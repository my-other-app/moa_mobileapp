import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finnet/common/models/events/store_model.dart';
import 'package:finnet/features/events/presentation/widgets/merch_picker.dart';

void main() {
  final catalog = StoreCatalog(enabled: true, items: const [
    StoreItem(id: 'tee', name: 'Hack Night tee', price: 450, variants: [StoreVariant(id: 'm', label: 'M', left: 30)]),
    StoreItem(id: 'kit', name: 'Starter kit', price: 890, left: 1),
  ]);

  testWidgets('needs a size before counting a sized item, and totals the picks', (tester) async {
    var picks = <String, StorePick>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: MerchPicker(catalog: catalog, picks: picks, onChanged: (next) => setState(() => picks = next)),
          ),
        ),
      ),
    ));
    expect(find.text('Add to your ticket'), findsOneWidget);
    expect(find.text('₹450 each'), findsOneWidget);
    // The tee's plus is off until a size is picked.
    IconButton button(String tooltip) => tester.widget<IconButton>(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)));
    expect(button('One more Hack Night tee').onPressed, isNull);
    await tester.tap(find.text('M'));
    await tester.pump();
    expect(picks['tee']?.variantId, 'm');
    expect(picks['tee']?.qty, 1);
    // The kit has one left: one is the most.
    await tester.tap(find.byTooltip('One more Starter kit'));
    await tester.pump();
    expect(picks['kit']?.qty, 1);
    expect(button('One more Starter kit').onPressed, isNull);
    expect(find.text('₹1,340'), findsOneWidget);
    expect(MerchPicker.rupees(197046), '₹1,97,046');
  });

  testWidgets('shows nothing when the event sells nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MerchPicker(catalog: StoreCatalog.empty, picks: const {}, onChanged: (_) {}))));
    expect(find.text('Add to your ticket'), findsNothing);
  });
}
