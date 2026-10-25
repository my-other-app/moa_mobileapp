import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/utils/saved_feed.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/events/presentation/pages/no_registered_event_page.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/providers/event_cancellation_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';

class UpcomingEventsPage extends ConsumerStatefulWidget {
  const UpcomingEventsPage({super.key});

  @override
  ConsumerState<UpcomingEventsPage> createState() =>
      _UpcomingEventsPageState();
}

class _UpcomingEventsPageState extends ConsumerState<UpcomingEventsPage>
    with AutomaticKeepAliveClientMixin, SavedFirstPageFeed<UpcomingEventsPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  String feedPage(int offset) =>
      '/events/list?is_registered=true&is_ended=false&offset=$offset&limit=${SavedFirstPageFeed.pageSize}';

  /// The person's own registrations, with their tickets: encrypted, and
  /// never pruned to make room.
  @override
  CachePolicy get feedPolicy => CachePolicy.personalKept;

  @override
  String get feedErrorFallback => 'Could not load upcoming events.';

  @override
  void initState() {
    super.initState();
    fetchFirstPage();
  }

  /// The list came from the server: every ticket on it is saved for the
  /// door in the background -- its details, its QR, the club's design and
  /// its PDF -- so a registration made since the app started opens with no
  /// network too, not only those saved at start-up.
  @override
  void onFirstPage(List<dynamic> items, {required bool fresh}) {
    if (!fresh || items.isEmpty) return;
    ref
        .read(savedTicketsProvider.notifier)
        .refreshIfOlderThan(const Duration(seconds: 30));
  }

  /// Opens the event straight into paying; the list is fetched again after,
  /// so a paid registration comes back with its ticket.
  Future<void> _finishPayment(Map<String, dynamic> event) async {
    final id = event['id'];
    if (id is! num) return;
    await context.push('/events/${id.toInt()}',
        extra: {'status': finishPaymentStatus});
    if (mounted) await fetchFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return Container(
        color: Colors.white,
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      // Nothing saved of the list and no network: the tickets saved on the
      // phone, if there are any, rather than an error.
      return Container(
        color: Colors.white,
        child: SavedTicketsFallback(
          fallback: ErrorView(
            message: errorMessage,
            onRetry: fetchFirstPage,
          ),
        ),
      );
    }

    if (events.isEmpty) {
      return NoRegisteredEventPage();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: onFeedScroll,
      child: RefreshIndicator(
        onRefresh: fetchFirstPage,
        child: ListView.separated(
          primary: true,
          padding: const EdgeInsets.all(16),
          itemCount: events.length + (hasMore ? 1 : 0),
          separatorBuilder: (context, index) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
          ),
          itemBuilder: (context, index) {
            if (index == events.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final event = Map<String, dynamic>.from(
                events[index] as Map? ?? const <String, dynamic>{});
            // A registration still waiting for its payment has no ticket to
            // view: its card says "Payment due" and offers FINISH PAYMENT,
            // after which the list is fetched again. A cancelled event's
            // says so instead.
            return _RegistrationCard(
              event: event,
              onFinishPayment: () => _finishPayment(event),
            );
          },
        ),
      ),
    );
  }
}

/// One registration's card, told whether its event was called off: by the
/// row itself when the server says, else by the event's public page (the
/// list doesn't say today). Only the cards drawn ask, each once in a while
/// ([EventCancellationLookups]).
class _RegistrationCard extends StatefulWidget {
  const _RegistrationCard({required this.event, required this.onFinishPayment});

  final Map<String, dynamic> event;
  final VoidCallback onFinishPayment;

  @override
  State<_RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<_RegistrationCard> {
  EventCancellation? _looked;

  @override
  void initState() {
    super.initState();
    _lookUp();
  }

  @override
  void didUpdateWidget(_RegistrationCard old) {
    super.didUpdateWidget(old);
    if (_refOf(old.event) != _refOf(widget.event)) {
      _looked = null;
      _lookUp();
    }
  }

  static String _refOf(Map<String, dynamic> event) {
    final slug = event['slug'];
    final id = event['id'];
    if (slug is String && slug.trim().isNotEmpty) return slug.trim();
    return id is num ? '${id.toInt()}' : '';
  }

  Future<void> _lookUp() async {
    if (EventCancellation.of(widget.event) != null) return;
    final asked = _refOf(widget.event);
    final found = await EventCancellationLookups.instance.of(asked);
    if (!mounted || found == null || asked != _refOf(widget.event)) return;
    setState(() => _looked = found);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return eventCardFromJson(
      event,
      status: registeredCardStatus(event),
      ticketUrl:
          event['ticket_url'] is String ? event['ticket_url'] as String : null,
      onFinishPayment: widget.onFinishPayment,
      cancellation: EventCancellation.of(event) ?? _looked,
    );
  }
}
