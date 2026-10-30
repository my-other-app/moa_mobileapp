import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';

final certificatePinStoreProvider = Provider<CertificatePinStore>((ref) {
  return CertificatePinStore(ref.watch(secureStorageServiceProvider));
});

/// Which certificates the user has pinned.
///
/// Device-local. The server has no concept of a pinned certificate -- there
/// is no certificates table at all, only registrations the organiser has
/// issued one to -- so
/// pinning cannot sync across devices or survive a reinstall. The design
/// calls for the feature and this is the honest extent of it without a
/// schema change; the alternative was a tab that did nothing.
class CertificatePinStore {
  static const _key = 'pinned_certificate_ticket_ids';

  final SecureStorageService _storage;

  CertificatePinStore(this._storage);

  Future<Set<String>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return <String>{};
      return raw.split(',').where((id) => id.isNotEmpty).toSet();
    } catch (e) {
      // Storage can fail on a device with a damaged keychain. An empty set
      // means "nothing pinned", which degrades to the All tab rather than
      // taking the screen down.
      debugPrint('CertificatePinStore.read failed: $e');
      return <String>{};
    }
  }

  /// Forget every pin: they name the person's certificates, and go with
  /// them at sign-out.
  Future<void> clear() => _storage.delete(key: _key);

  Future<Set<String>> toggle(String ticketId) async {
    final pinned = await read();
    if (!pinned.remove(ticketId)) pinned.add(ticketId);
    await _storage.write(key: _key, value: pinned.join(','));
    return pinned;
  }
}
