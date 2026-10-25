import 'package:flutter/material.dart';

import 'package:finnet/features/events/domain/ticketing.dart';

const _ink = Color(0xFF2C333D);
const _muted = Color(0xFF6B7280);

/// The event's ticket types to choose from, shown only when it sells more
/// than one (`requires_choice`): each with its price and where it stands.
/// One that isn't on sale can't be chosen; a sold-out one with its waiting
/// list open offers that instead ([onJoinWaitlist]).
class TicketTypePicker extends StatelessWidget {
  const TicketTypePicker({
    super.key,
    required this.types,
    required this.selected,
    required this.onChanged,
    this.errorText,
    this.onJoinWaitlist,
    this.showPrices = true,
  });

  final List<TicketType> types;
  final int? selected;
  final ValueChanged<int> onChanged;
  final String? errorText;

  /// "Join the waiting list" on a sold-out type whose list is open; none
  /// when null.
  final VoidCallback? onJoinWaitlist;

  /// No prices on an iPhone for an event it doesn't sell (canSellInApp).
  final bool showPrices;

  static Key tileKey(int id) => ValueKey('ticket-type-$id');
  static const errorKey = ValueKey('ticket-type-error');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your ticket',
          style: TextStyle(
            color: _ink,
            fontSize: 12,
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        for (final type in types)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TypeTile(
              key: tileKey(type.id),
              type: type,
              chosen: type.id == selected,
              showPrice: showPrices,
              onTap: type.onSale ? () => onChanged(type.id) : null,
              onJoinWaitlist: type.waitlist ? onJoinWaitlist : null,
            ),
          ),
        if (errorText != null)
          Text(
            errorText!,
            key: errorKey,
            style: const TextStyle(color: Color(0xFFCC0000), fontSize: 12),
          ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    super.key,
    required this.type,
    required this.chosen,
    required this.showPrice,
    this.onTap,
    this.onJoinWaitlist,
  });

  final TicketType type;
  final bool chosen;
  final bool showPrice;
  final VoidCallback? onTap;
  final VoidCallback? onJoinWaitlist;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final status = type.statusLine;
    return Semantics(
      selected: chosen,
      button: enabled,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: chosen ? const Color(0xFFF3F4F6) : Colors.white,
            border: Border.all(
              color: chosen ? _ink : const Color(0xFFD1D5DB),
              width: chosen ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                chosen ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: enabled ? _ink : const Color(0xFFD1D5DB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: enabled ? const Color(0xFF1E1E1E) : _muted,
                      ),
                    ),
                    if (type.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        type.description!,
                        style: const TextStyle(fontSize: 12.5, color: _muted),
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: type.onSale
                              ? const Color(0xFFB45309)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                    if (onJoinWaitlist != null)
                      TextButton(
                        key: ValueKey('ticket-type-waitlist-${type.id}'),
                        onPressed: onJoinWaitlist,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          foregroundColor: _ink,
                        ),
                        child: const Text('Join the waiting list'),
                      ),
                  ],
                ),
              ),
              if (showPrice)
                Text(
                  priceLabel(type.price),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled ? const Color(0xFF1E1E1E) : _muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The event page's "Tickets": each type with its price and where it
/// stands, for an event that sells more than one. A sold-out one with its
/// waiting list open offers it ([onJoinWaitlist]).
class TicketTypesList extends StatelessWidget {
  const TicketTypesList({
    super.key,
    required this.types,
    this.onJoinWaitlist,
  });

  final List<TicketType> types;
  final ValueChanged<TicketType>? onJoinWaitlist;

  static const listKey = ValueKey('event-ticket-types');

  @override
  Widget build(BuildContext context) {
    return Column(
      key: listKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tickets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final type in types)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (type.description != null)
                        Text(type.description!,
                            style:
                                const TextStyle(fontSize: 12.5, color: _muted)),
                      if (type.statusLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            type.statusLine!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: type.onSale
                                  ? const Color(0xFFB45309)
                                  : _muted,
                            ),
                          ),
                        ),
                      if (type.waitlist && onJoinWaitlist != null)
                        TextButton(
                          key: ValueKey('event-type-waitlist-${type.id}'),
                          onPressed: () => onJoinWaitlist!(type),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            foregroundColor: _ink,
                          ),
                          child: const Text('Join the waiting list'),
                        ),
                    ],
                  ),
                ),
                Text(priceLabel(type.price),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
