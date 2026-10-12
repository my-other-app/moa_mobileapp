import 'package:flutter_test/flutter_test.dart';
import 'package:finnet/common/models/events/store_model.dart';

void main() {
  final catalog = StoreCatalog.fromJson({
    'enabled': true,
    'items': [
      {'id': 'tee', 'name': 'Hack Night tee', 'price': 450, 'left': null, 'variants': [{'id': 's', 'label': 'S', 'left': 2}, {'id': 'm', 'label': 'M', 'left': 30}]},
      {'id': 'kit', 'name': 'Starter kit', 'description': 'ESP32-S3', 'price': 890.0, 'left': 1, 'variants': []},
      {'id': 'sticker', 'name': 'Sticker pack', 'price': 0, 'left': 200, 'variants': []},
    ],
  });

  test('parses the catalogue, tolerating what is missing', () {
    expect(catalog.hasAnything, isTrue);
    expect(catalog.items.length, 3);
    expect(catalog.items.first.hasSizes, isTrue);
    expect(catalog.items[1].left, 1);
    expect(catalog.items[2].isFree, isTrue);
    expect(StoreCatalog.fromJson({}).hasAnything, isFalse);
    expect(StoreCatalog.fromJson({'enabled': true, 'items': [<String, dynamic>{}]}).items.first.name, '');
  });

  test('only complete picks go, capped at what is left, and the total follows', () {
    final picks = {
      'tee': const StorePick(qty: 2),
      'kit': const StorePick(qty: 1),
    };
    expect(picksToPayload(catalog, picks), [
      {'item_id': 'kit', 'variant_id': null, 'qty': 1},
    ]);
    expect(maxQty(catalog.items[1], const StorePick()), 1);
    expect(maxQty(catalog.items.first, const StorePick(variantId: 's')), 2);
    expect(maxQty(catalog.items[2], const StorePick()), 10);
    final withSize = {'tee': const StorePick(qty: 1, variantId: 'm'), 'kit': const StorePick(qty: 1)};
    expect(picksToPayload(catalog, withSize).length, 2);
    expect(picksTotal(catalog, withSize), 1340);
  });
}
