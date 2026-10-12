/// What an event sells with its ticket, as `GET /events/{id}/store/catalog`
/// returns it, and what a guest picks from it.
class StoreVariant {
  final String id;
  final String label;
  final int left;

  const StoreVariant({required this.id, required this.label, required this.left});

  factory StoreVariant.fromJson(Map<String, dynamic> json) => StoreVariant(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        left: (json['left'] as num?)?.toInt() ?? 0,
      );
}

class StoreItem {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final double price;

  /// Pieces left when the item has no sizes; null when the sizes carry it.
  final int? left;
  final List<StoreVariant> variants;

  const StoreItem({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.price,
    this.left,
    this.variants = const [],
  });

  bool get hasSizes => variants.isNotEmpty;
  bool get isFree => price <= 0;

  factory StoreItem.fromJson(Map<String, dynamic> json) => StoreItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: _blank(json['description'] as String?),
        photoUrl: _blank(json['photo_url'] as String?),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        left: (json['left'] as num?)?.toInt(),
        variants: ((json['variants'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StoreVariant.fromJson)
            .toList(),
      );
}

class StoreCatalog {
  final bool enabled;
  final List<StoreItem> items;

  const StoreCatalog({required this.enabled, required this.items});

  static const empty = StoreCatalog(enabled: false, items: []);

  bool get hasAnything => enabled && items.isNotEmpty;

  factory StoreCatalog.fromJson(Map<String, dynamic> json) => StoreCatalog(
        enabled: json['enabled'] as bool? ?? false,
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StoreItem.fromJson)
            .toList(),
      );
}

/// One pick: an item, its size when it has sizes, and how many.
class StorePick {
  final int qty;
  final String? variantId;

  const StorePick({this.qty = 0, this.variantId});

  StorePick copyWith({int? qty, String? variantId, bool clearVariant = false}) =>
      StorePick(qty: qty ?? this.qty, variantId: clearVariant ? null : (variantId ?? this.variantId));
}

/// The picks as the registration sends them: only complete ones go.
List<Map<String, dynamic>> picksToPayload(StoreCatalog catalog, Map<String, StorePick> picks) {
  final out = <Map<String, dynamic>>[];
  for (final item in catalog.items) {
    final p = picks[item.id];
    if (p == null || p.qty <= 0) continue;
    if (item.hasSizes && p.variantId == null) continue;
    out.add({'item_id': item.id, 'variant_id': item.hasSizes ? p.variantId : null, 'qty': p.qty});
  }
  return out;
}

/// What the picks add up to.
double picksTotal(StoreCatalog catalog, Map<String, StorePick> picks) {
  var sum = 0.0;
  for (final item in catalog.items) {
    final p = picks[item.id];
    if (p != null && p.qty > 0) sum += item.price * p.qty;
  }
  return sum;
}

/// The most a guest may take of one item: what is left, capped at ten.
int maxQty(StoreItem item, StorePick pick) {
  int left;
  if (item.hasSizes) {
    final v = item.variants.where((v) => v.id == pick.variantId).toList();
    left = v.isEmpty ? 10 : v.first.left;
  } else {
    left = item.left ?? 10;
  }
  return left.clamp(0, 10);
}

String? _blank(String? v) => (v == null || v.trim().isEmpty) ? null : v;
