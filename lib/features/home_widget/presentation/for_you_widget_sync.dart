import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/presentation/providers/discover_place_provider.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/home_widget/data/for_you_store.dart';
import 'package:finnet/features/home_widget/data/widget_store.dart';
import 'package:finnet/features/home_widget/domain/events_for_you.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Writes what the "For you" events widget lists (docs/HOME_WIDGETS.md).
/// The same list twice is written once (a newer read of the same list is
/// written again only after [rewriteAfter], so the widget knows it is
/// recent and doesn't ask the server itself meanwhile).
class ForYouWidgetSync {
  ForYouWidgetSync(
    this._store, {
    DateTime Function()? now,
    this.rewriteAfter = const Duration(minutes: 30),
  }) : _now = now ?? DateTime.now;

  final WidgetStore _store;
  final DateTime Function() _now;
  final Duration rewriteAfter;

  /// What was written last, less its time; and when.
  String? _written;
  DateTime? _writtenAt;

  /// List what the front page [home] holds for [ask].
  Future<void> show(DiscoverHome home, ForYouAsk ask) {
    final now = _now();
    return _write(ForYouSnapshot(
      pick: pickFromHome(home, ask, now),
      ask: ask,
      fetchedAt: now.toUtc(),
    ));
  }

  /// Nothing read for [ask] yet: the widget asks the front page itself.
  Future<void> unread(ForYouAsk ask) => _write(ForYouSnapshot.unread(ask));

  Future<void> _write(ForYouSnapshot snapshot) {
    final json = snapshot.toJson();
    final content = jsonEncode({...json}..remove('fetched_at'));
    final now = _now();
    final recent =
        _writtenAt != null && now.difference(_writtenAt!) < rewriteAfter;
    if (content == _written && recent) return Future.value();
    _written = content;
    _writtenAt = now;
    return _store.write(jsonEncode(json));
  }

  Future<void> redraw() => _store.redraw();

  /// Whether a "For you" widget is on a home screen.
  Future<bool> isPlaced() => _store.isPlaced();
}

/// The app's [ForYouWidgetSync], one per session (SessionScope).
final forYouWidgetSyncProvider = Provider<ForYouWidgetSync>(
    (ref) => ForYouWidgetSync(ref.watch(forYouStoreProvider)));

/// The public API's address the widget asks the front page at: the app's
/// own (`API_BASE_URL`). A provider so tests can name one.
final forYouApiBaseProvider = Provider<String>((ref) => Env.apiBaseUrl);

/// The person's topics, by id: the topics (interest categories) of the
/// interests on their account.
List<int> topicsOf(UserProfile? profile) => [
      for (final interest in profile?.interests ?? const <Interest>[])
        if (interest.categoryId != null) interest.categoryId!,
    ];

/// What signing out does to the events widget (SessionCaches): the list
/// asked again without the last person's topics -- the widget asks the
/// front page itself on its next draw. The place stays: it belongs to the
/// phone (the discover lists keep it across sign-outs too).
Future<void> showSignedOutOnForYouWidget(WidgetStore store,
    {required String api, DiscoverPlaceState? place}) {
  final ask = ForYouAsk.about(api: api, place: place?.place);
  return store.write(jsonEncode(ForYouSnapshot.unread(ask).toJson()));
}

/// Keeps the "For you" widget current while the app is open.
///
/// Sits around the tabs (the main shell), beside the other widgets' scopes.
/// Only while a "For you" widget is on a home screen does it do anything:
/// it follows the discover front page ([discoverHomeProvider] -- what the
/// Home tab shows, read once more for the widget when the tab hasn't been
/// opened) and writes the events the widget lists from it, for the kept
/// place and the person's topics; again whenever the page is read again
/// (pull to refresh, back online, another city picked) or the person's
/// interests change; and it redraws the widget each time the app comes back
/// to the front. With no widget placed, nothing is read or written for it.
///
/// The widget asks the same public page itself every few hours while the
/// app is closed (ForYouWidget.swift, ForYouRefreshWorker.kt).
class ForYouWidgetSyncScope extends ConsumerStatefulWidget {
  const ForYouWidgetSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ForYouWidgetSyncScope> createState() =>
      _ForYouWidgetSyncScopeState();
}

class _ForYouWidgetSyncScopeState extends ConsumerState<ForYouWidgetSyncScope>
    with WidgetsBindingObserver {
  bool _started = false;

  /// Whether a widget is on a home screen; null until asked.
  bool? _placed;

  ProviderSubscription<AsyncValue<DiscoverHome>>? _home;
  ProviderSubscription<ProfileState>? _account;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopFollowing();
    super.dispose();
  }

  void _start() {
    if (!mounted) return;
    _started = true;
    unawaited(_followIfPlaced());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || !_started) return;
    unawaited(_followIfPlaced(redraw: true));
  }

  ForYouAsk _ask() {
    final signedIn = ref.read(isAuthenticatedProvider);
    final topics = signedIn && ref.exists(profileProvider)
        ? topicsOf(ref.read(profileProvider).profile)
        : const <int>[];
    return ForYouAsk.about(
      api: ref.read(forYouApiBaseProvider),
      place: ref.read(discoverPlaceProvider).place,
      topics: topics,
    );
  }

  void _publish() {
    if (!mounted || _placed != true) return;
    final home = ref.read(discoverHomeProvider).valueOrNull;
    if (home == null) return;
    unawaited(ref.read(forYouWidgetSyncProvider).show(home, _ask()));
  }

  /// With a widget on a home screen: follow the front page and the
  /// person's interests. Otherwise stop.
  Future<void> _followIfPlaced({bool redraw = false}) async {
    final sync = ref.read(forYouWidgetSyncProvider);
    final placed = await sync.isPlaced();
    if (!mounted) return;
    _placed = placed;
    if (!placed) return _stopFollowing();
    if (redraw) unawaited(sync.redraw());
    _followAccount();
    _home ??= ref.listenManual<AsyncValue<DiscoverHome>>(
        discoverHomeProvider, (_, __) => _publish());
    _publish();
  }

  /// The person's interests, for their topics: read if nothing has yet
  /// (signed in), and followed.
  void _followAccount() {
    if (_account != null || !ref.read(isAuthenticatedProvider)) return;
    ref.read(profileProvider);
    _account = ref.listenManual<ProfileState>(profileProvider, (was, now) {
      final before = topicsOf(was?.profile).join(',');
      if (before != topicsOf(now.profile).join(',')) _publish();
    });
  }

  void _stopFollowing() {
    _home?.close();
    _home = null;
    _account?.close();
    _account = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isAuthenticatedProvider, (was, now) {
      if (!now) {
        _account?.close();
        _account = null;
      } else {
        _followAccountIfPlaced();
      }
      _publish();
    });
    // A city picked: the front page is read again for it, and written as
    // it comes (the listener above); nothing to do here.
    return widget.child;
  }

  void _followAccountIfPlaced() {
    if (_placed == true) _followAccount();
  }
}
