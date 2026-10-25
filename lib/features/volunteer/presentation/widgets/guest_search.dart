import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';

/// Find a guest by name, email, ticket or admission number
/// (`GET /gate/search?q=`), and [onPick] one: to check them in by hand, or
/// to hand over what they are owed.
class GuestSearch extends ConsumerStatefulWidget {
  const GuestSearch({
    super.key,
    required this.eventId,
    required this.onPick,
    this.hint = 'Name, email or ticket code',
    this.debounce = const Duration(milliseconds: 350),
  });

  static const fieldKey = ValueKey('guest-search-field');
  static ValueKey<String> rowKey(String id) => ValueKey('guest-$id');

  final int eventId;
  final void Function(GateAttendee guest) onPick;
  final String hint;
  final Duration debounce;

  @override
  ConsumerState<GuestSearch> createState() => _GuestSearchState();
}

class _GuestSearchState extends ConsumerState<GuestSearch> {
  final _query = TextEditingController();
  Timer? _wait;
  List<GateAttendee>? _found;
  String? _error;
  bool _searching = false;
  int _asked = 0;

  @override
  void dispose() {
    _wait?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _wait?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _found = null;
        _error = null;
        _searching = false;
      });
      return;
    }
    _wait = Timer(widget.debounce, () => _search(text.trim()));
  }

  Future<void> _search(String q) async {
    final asked = ++_asked;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await ref.read(gateApiProvider).search(widget.eventId, q);
      if (!mounted || asked != _asked) return;
      setState(() {
        _found = found;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || asked != _asked) return;
      setState(() {
        _searching = false;
        _error = gateErrorMessage(e, "The search didn't work. Try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: GuestSearch.fieldKey,
            controller: _query,
            onChanged: _changed,
            onSubmitted: (q) {
              _wait?.cancel();
              if (q.trim().length >= 2) _search(q.trim());
            },
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _error != null
              ? _message(_error!)
              : found == null
                  ? _message('Type at least two letters of their name, '
                      'their email, or their ticket code.')
                  : found.isEmpty
                      ? _message('Nobody on the list matches '
                          '"${_query.text.trim()}".')
                      : ListView.separated(
                          itemCount: found.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _row(found[i]),
                        ),
        ),
      ],
    );
  }

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF4B5563))),
      );

  Widget _row(GateAttendee g) {
    final at = g.checkedInAt;
    final status = at != null
        ? 'Checked in ${DateFormat('HH:mm').format(at.toLocal())}'
        : (g.isPaid ? 'Not checked in' : 'Not paid');
    return ListTile(
      key: GuestSearch.rowKey(g.id),
      tileColor: Colors.white,
      title: Text(g.name.isEmpty ? g.ticketId : g.name,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        g.ticketId,
        if (g.admissionNo != null) 'No. ${g.admissionNo}',
        if (g.role != 'attendee') g.role,
      ].join(' · ')),
      trailing: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: at != null
              ? const Color(0xFF15803D)
              : (g.isPaid ? const Color(0xFF6B7280) : const Color(0xFFB91C1C)),
        ),
      ),
      onTap: () => widget.onPick(g),
    );
  }
}
