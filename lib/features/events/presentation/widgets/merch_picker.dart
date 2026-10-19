import 'package:flutter/material.dart';
import 'package:finnet/common/models/events/store_model.dart';
import 'package:finnet/shared/widgets/quantity_stepper.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// The shelf on the registration form: each item with its price, a size
/// where it has sizes, and a count. The picks go with the registration and
/// are paid in the same checkout as the ticket.
class MerchPicker extends StatelessWidget {
  final StoreCatalog catalog;
  final Map<String, StorePick> picks;
  final ValueChanged<Map<String, StorePick>> onChanged;

  const MerchPicker({super.key, required this.catalog, required this.picks, required this.onChanged});

  static String rupees(double amount) {
    final whole = amount.truncate();
    final s = whole.toString();
    // en-IN grouping: last three, then pairs.
    if (s.length <= 3) return '₹$s';
    final head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buf.write(',');
      buf.write(head[i]);
    }
    return '₹$buf,$tail';
  }

  void _set(String id, StorePick next) => onChanged({...picks, id: next});

  @override
  Widget build(BuildContext context) {
    if (!catalog.hasAnything) return const SizedBox.shrink();
    final total = picksTotal(catalog, picks);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2C333D), width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add to your ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text('Paid together with the registration. Collect at the door.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          for (final item in catalog.items) _ItemRow(item: item, pick: picks[item.id] ?? const StorePick(), onPick: (p) => _set(item.id, p)),
          if (total > 0) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Merchandise', style: TextStyle(fontSize: 14)),
                Text(rupees(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final StoreItem item;
  final StorePick pick;
  final ValueChanged<StorePick> onPick;

  const _ItemRow({required this.item, required this.pick, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final max = maxQty(item, pick);
    final needsSize = item.hasSizes && pick.variantId == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: item.photoUrl != null
                      ? AppNetworkImage(url: item.photoUrl, width: 48, height: 48)
                      : Container(color: const Color(0xFFEFEFEF), child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF9A9A9A))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E))),
                    if (item.description != null) Text(item.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    Text(item.isFree ? 'Free with your ticket' : '${MerchPicker.rupees(item.price)} each', style: const TextStyle(fontSize: 12.5, color: Color(0xFF2C333D))),
                  ],
                ),
              ),
              QuantityStepper(
                label: item.name,
                value: pick.qty,
                max: needsSize ? 0 : max,
                onChanged: (q) => onPick(pick.copyWith(qty: q)),
              ),
            ],
          ),
          if (item.hasSizes)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 58),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in item.variants)
                    ChoiceChip(
                      label: Text(v.left <= 5 ? '${v.label} · ${v.left} left' : v.label),
                      selected: pick.variantId == v.id,
                      onSelected: v.left <= 0
                          ? null
                          : (on) => onPick(on ? pick.copyWith(variantId: v.id, qty: pick.qty == 0 ? 1 : pick.qty) : pick.copyWith(clearVariant: true, qty: 0)),
                      selectedColor: const Color(0xFF17A58F).withValues(alpha: 0.18),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
