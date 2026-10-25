import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';

/// What one guest is owed at the door, and handing it over: the event's
/// swag, from their own record (`GET /gate/merch/{reg}`, `POST
/// /gate/merch/{item}/collect`), and what they bought from the shelf (`GET
/// /gate/store/{reg}`, `POST /gate/store/{order}/handover`). As the club
/// dashboard's Merch tab.
class MerchHandover extends ConsumerStatefulWidget {
  const MerchHandover({
    super.key,
    required this.eventId,
    required this.guest,
    this.hasMerch = true,
    this.hasStore = true,
    this.door,
  });

  static ValueKey<String> handOverKey(String itemId) =>
      ValueKey('merch-hand-over-$itemId');
  static ValueKey<String> sizeKey(String itemId, String size) =>
      ValueKey('merch-size-$itemId-$size');
  static ValueKey<String> orderKey(String orderId) =>
      ValueKey('order-hand-over-$orderId');

  final int eventId;
  final GateAttendee guest;
  final bool hasMerch;
  final bool hasStore;
  final String? door;

  @override
  ConsumerState<MerchHandover> createState() => _MerchHandoverState();
}

class _MerchHandoverState extends ConsumerState<MerchHandover> {
  AttendeeMerch? _merch;
  List<StoreOrder>? _orders;
  String? _error;
  bool _loading = true;
  String? _working;

  @override
  void initState() {
    super.initState();
    _load();
  }

  GateApi get _api => ref.read(gateApiProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final merch = widget.hasMerch
          ? _api.merchFor(widget.eventId, widget.guest.id)
          : Future.value(const AttendeeMerch(items: []));
      final orders = widget.hasStore
          ? _api.ordersFor(widget.eventId, widget.guest.id)
          : Future.value(const <StoreOrder>[]);
      final m = await merch;
      final o = await orders;
      if (!mounted) return;
      setState(() {
        _merch = m;
        _orders = o;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = gateErrorMessage(e, "Couldn't read what they are owed.");
      });
    }
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _collect(MerchOwed item, {String? size}) async {
    setState(() => _working = item.itemId);
    try {
      final r = await _api.collect(widget.eventId,
          itemId: item.itemId,
          registrationId: widget.guest.id,
          size: size,
          door: widget.door);
      _say(r.collected
          ? 'Handed over: ${item.name}'
              '${r.variantLabel == null ? '' : ' (${r.variantLabel})'}.'
          : '${item.name}: '
              '${merchStatusNote(r.status, size: r.variantLabel)}');
    } catch (e) {
      _say(gateErrorMessage(e, "${item.name} wasn't handed over. Try again."));
    } finally {
      if (mounted) setState(() => _working = null);
      await _load();
    }
  }

  Future<void> _handOver(StoreOrder order) async {
    setState(() => _working = order.id);
    try {
      await _api.handOver(widget.eventId, order.id);
      _say('Order handed over: ${order.summary}.');
    } catch (e) {
      _say(gateErrorMessage(e, "The order wasn't handed over. Try again."));
    } finally {
      if (mounted) setState(() => _working = null);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guest;
    final items = _merch?.items ?? const <MerchOwed>[];
    final orders = _orders ?? const <StoreOrder>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      shrinkWrap: true,
      children: [
        Text(g.name.isEmpty ? g.ticketId : g.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(g.ticketId, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        if (_loading && _merch == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Column(
            children: [
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          )
        else ...[
          if (widget.hasMerch) ...[
            const _Heading('TO HAND OUT'),
            if (items.isEmpty)
              const _Empty('Nothing for them in the event\'s swag.'),
            for (final item in items) _item(item),
          ],
          if (widget.hasStore) ...[
            const SizedBox(height: 12),
            const _Heading('THEIR ORDERS'),
            if (orders.isEmpty) const _Empty('No paid orders from the shelf.'),
            for (final order in orders) _order(order),
          ],
        ],
      ],
    );
  }

  Widget _item(MerchOwed item) {
    final busy = _working == item.itemId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (item.collectable)
                  FilledButton(
                    key: MerchHandover.handOverKey(item.itemId),
                    onPressed:
                        busy || _working != null ? null : () => _collect(item),
                    child: Text(busy ? 'Handing over…' : 'Hand over'),
                  )
                else if (item.collected)
                  const Icon(Icons.check_circle, color: Color(0xFF15803D)),
              ],
            ),
            const SizedBox(height: 4),
            Text(merchNote(item),
                style: const TextStyle(color: Color(0xFF4B5563))),
            if (item.needsSize && item.choices.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in item.choices)
                    ActionChip(
                      key: MerchHandover.sizeKey(item.itemId, c.label),
                      label: Text('${c.label} · ${c.remaining} left'),
                      onPressed: c.remaining > 0 && _working == null
                          ? () => _collect(item, size: c.label)
                          : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _order(StoreOrder order) {
    final busy = _working == order.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.summary.isEmpty ? 'Order' : order.summary,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final l in order.lines)
                    Text(
                        '${l.qty} × ${l.name}'
                        '${l.variant == null ? '' : ' (${l.variant})'}',
                        style: const TextStyle(color: Color(0xFF4B5563))),
                  if (order.handedOver)
                    const Text('Handed over',
                        style: TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (order.toHandOver)
              FilledButton(
                key: MerchHandover.orderKey(order.id),
                onPressed:
                    busy || _working != null ? null : () => _handOver(order),
                child: Text(busy ? 'Handing over…' : 'Hand over'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 18,
                color: Color(0xFF2C333D))),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
      );
}
