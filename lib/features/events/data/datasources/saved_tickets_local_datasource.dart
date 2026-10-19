import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';

final savedTicketsLocalDataSourceProvider =
    Provider<SavedTicketsLocalDataSource>((ref) {
  return SavedTicketsLocalDataSource(ref.watch(secureStorageServiceProvider));
});

/// The person's tickets on the phone, in the platform's encrypted storage
/// (Keychain / Keystore-backed EncryptedSharedPreferences), as one list
/// under one key. A ticket is an entry pass: it is never written in plain.
class SavedTicketsLocalDataSource {
  SavedTicketsLocalDataSource(this._storage);

  final SecureStorageService _storage;

  /// Apart from the saved API answers (`saved:`), which have their own
  /// limits and pruning: tickets live until their event is over.
  static const key = 'offline_tickets.v1';

  Future<List<SavedTicket>> read() async {
    try {
      final text = await _storage.read(key: key);
      if (text == null || text.isEmpty) return const [];
      final decoded = jsonDecode(text);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (SavedTicket.fromJson(item) case final ticket?) ticket,
      ];
    } catch (e) {
      debugPrint('SavedTickets: could not read: $e');
      return const [];
    }
  }

  Future<void> write(List<SavedTicket> tickets) async {
    if (tickets.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(
      key: key,
      value: jsonEncode([for (final ticket in tickets) ticket.toJson()]),
    );
  }

  Future<void> clear() => _storage.delete(key: key);
}
