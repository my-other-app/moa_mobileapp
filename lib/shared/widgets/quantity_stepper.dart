import 'package:flutter/material.dart';

/// Minus, the count, plus — for picking how many of something.
class QuantityStepper extends StatelessWidget {
  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final String label;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final canLess = enabled && value > 0;
    final canMore = enabled && value < max;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2C333D), width: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'One less $label',
            icon: const Icon(Icons.remove, size: 18),
            onPressed: canLess ? () => onChanged(value - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          Semantics(
            label: '$label quantity',
            value: '$value',
            child: SizedBox(
              width: 22,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: value > 0 ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
          ),
          IconButton(
            tooltip: 'One more $label',
            icon: const Icon(Icons.add, size: 18),
            onPressed: canMore ? () => onChanged(value + 1) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
