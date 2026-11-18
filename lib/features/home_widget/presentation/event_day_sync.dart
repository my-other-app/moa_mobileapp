import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/home_widget/data/event_day_platform.dart';
import 'package:finnet/features/home_widget/domain/event_day.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

/// Puts the event-day card up, brings it up to date and takes it down
/// (docs/HOME_WIDGETS.md, "Event-day card"). One change at a time, in the
/// order asked.
class EventDayCards {
  EventDayCards(this._platform, this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final EventDayPlatform _platform;
  final EventDayStore _store;
  final DateTime Function() _now;

  EventDayChoices? _choices;
  Future<void> _turn = Future.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final done = _turn.then((_) => job());
    _turn = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<EventDayChoices> _read() async => _choices ??= await _store.read();

  Future<void> _save(EventDayChoices choices) async {
    if (choices == _choices) return;
    _choices = choices;
    await _store.write(choices);
  }

  /// Whether the card may be shown ("Event-day card on the lock screen").
  Future<bool> isOn() => _serial(() async => (await _read()).on);

  /// Bring the card in line with what the app knows: signed in or not, the
  /// tickets on the phone, the switch, the clock -- and [opened], the event
  /// whose ticket the person just opened, whose card comes up (again) when
  /// its day has come.
  Future<void> sync({
    required bool signedIn,
    required List<SavedTicket> tickets,
    int? opened,
  }) =>
      _serial(() async {
        final now = _now();
        final choices = (await _read()).prunedAt(now);
        final showing = await _platform.current();
        if (!signedIn || !choices.on) {
          if (showing != null) await _platform.end();
          return _save(choices);
        }
        final card = eventDayCardToShow(
          due: eventDayCardsDue(tickets, now),
          showing: showing,
          shownBefore: choices.shown.keys.toSet(),
          opened: opened,
        );
        if (card == null) {
          if (showing != null) await _platform.end();
          return _save(choices);
        }
        if (showing == card.eventId && await _platform.update(card)) {
          return _save(choices);
        }
        if (await _platform.start(card)) {
          return _save(choices.copyWith(shown: {
            ...choices.shown,
            card.eventId: card.endsAt.millisecondsSinceEpoch,
          }));
        }
        return _save(choices);
      });

  /// The Settings switch. Off takes the card down at once; on again, the
  /// card of a day that has come may go up again (the person asked for
  /// it), at the next [sync].
  Future<void> setOn(bool on) => _serial(() async {
        final choices = await _read();
        await _save(on
            ? choices.copyWith(on: true, shown: const {})
            : choices.copyWith(on: false));
        if (!on) await _platform.end();
      });

  /// Signing out: the card goes, and the events it was put up for are
  /// forgotten (the switch stays: it is the phone's).
  Future<void> forget() => _serial(() async {
        await _platform.end();
        final choices = await _read();
        await _save(choices.copyWith(shown: const {}));
      });
}

final eventDayCardsProvider = Provider<EventDayCards>((ref) => EventDayCards(
    ref.watch(eventDayPlatformProvider), ref.watch(eventDayStoreProvider)));

/// Whether this phone can show the card: the Settings row is there only
/// then.
final eventDaySupportedProvider = FutureProvider<bool>(
    (ref) => ref.watch(eventDayPlatformProvider).supported());

/// "Event-day card on the lock screen", in Settings: null while the saved
/// choice is read; on unless turned off.
final eventDaySettingProvider =
    StateNotifierProvider<EventDaySetting, bool?>((ref) {
  return EventDaySetting(ref.watch(eventDayCardsProvider), onChange: () {
    unawaited(ref.read(eventDayCardsProvider).sync(
          signedIn: ref.read(isAuthenticatedProvider),
          tickets: ref.read(savedTicketsProvider),
        ));
  });
});

class EventDaySetting extends StateNotifier<bool?> {
  EventDaySetting(this._cards, {this.onChange}) : super(null) {
    _loaded = _load();
  }

  final EventDayCards _cards;

  /// Run after the switch moved and was saved: turned on, the card of a
  /// day that has come goes up.
  final void Function()? onChange;
  late final Future<void> _loaded;
  bool _changed = false;

  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    final on = await _cards.isOn();
    if (!mounted || _changed) return;
    state = on;
  }

  Future<void> set(bool on) async {
    if (state == on) return;
    _changed = true;
    state = on;
    try {
      await _cards.setOn(on);
      onChange?.call();
    } catch (e) {
      debugPrint('EventDaySetting: $e');
    }
  }
}

/// The Settings row: the switch and a line saying what it does, then a
/// divider. Nothing on a phone that can't show the card, or while the
/// saved choice is read.
class EventDayRow extends ConsumerWidget {
  const EventDayRow({super.key});

  static const rowKey = ValueKey('settings-event-day-card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(eventDaySupportedProvider).valueOrNull;
    final on = ref.watch(eventDaySettingProvider);
    if (supported != true || on == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          key: rowKey,
          emoji: '⏱️',
          label: 'Event-day card on the lock screen',
          value: on,
          onChanged: ref.read(eventDaySettingProvider.notifier).set,
        ),
        const SettingsCaption(
          'On the day of an event you have a ticket for, a card on your lock '
          'screen counts down to the start and opens your ticket. It never '
          'shows the ticket’s code.',
        ),
        const SettingsDivider(),
      ],
    );
  }
}

/// Keeps the event-day card in line while the app is open: when it starts
/// (once the saved tickets are read), each time it comes back to the
/// front, when the tickets change (one bought, one revoked, the event
/// called off) and at sign-in and sign-out. Sits around the tabs (the main
/// shell), beside the widgets' scopes.
class EventDaySyncScope extends ConsumerStatefulWidget {
  const EventDaySyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EventDaySyncScope> createState() => _EventDaySyncScopeState();
}

class _EventDaySyncScopeState extends ConsumerState<EventDaySyncScope>
    with WidgetsBindingObserver {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted) return;
    try {
      await ref.read(savedTicketsProvider.notifier).loaded;
    } catch (e) {
      debugPrint('EventDaySync: saved tickets not read: $e');
    }
    if (!mounted) return;
    _started = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _started) _sync();
  }

  void _sync() {
    if (!mounted || !_started) return;
    unawaited(ref.read(eventDayCardsProvider).sync(
          signedIn: ref.read(isAuthenticatedProvider),
          tickets: ref.read(savedTicketsProvider),
        ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(savedTicketsProvider, (_, __) => _sync());
    ref.listen<bool>(isAuthenticatedProvider, (_, __) => _sync());
    return widget.child;
  }
}

/// Around a ticket's screen: opening the ticket to an event whose day has
/// come puts its card up (again, if the person had put it away).
class EventDayOnOpen extends ConsumerStatefulWidget {
  const EventDayOnOpen({super.key, required this.eventId, required this.child});

  final int? eventId;
  final Widget child;

  @override
  ConsumerState<EventDayOnOpen> createState() => _EventDayOnOpenState();
}

class _EventDayOnOpenState extends ConsumerState<EventDayOnOpen> {
  @override
  void initState() {
    super.initState();
    final id = widget.eventId;
    if (id == null || id <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(eventDayCardsProvider).sync(
            signedIn: ref.read(isAuthenticatedProvider),
            tickets: ref.read(savedTicketsProvider),
            opened: id,
          ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
