import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/data/datasources/certificate_pin_store.dart';
import 'package:finnet/features/profile/data/datasources/certificate_remote_datasource.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/domain/entities/certificate_style.dart';
import 'package:finnet/features/profile/domain/entities/certificate_verification.dart';

/// Every certificate the user has earned, newest first.
///
/// Self-loading, so a screen that watches it does not also have to remember
/// to fetch it. The list saved on this phone comes first, then the
/// server's.
final certificatesProvider = StreamProvider<List<Certificate>>((ref) {
  ref.watch(backOnlineProvider);
  final source = ref.watch(certificateRemoteDataSourceProvider);
  return savedThenFresh(
    saved: source.savedCertificates,
    fresh: source.getMyCertificates,
  );
});

/// Certificate [ticketId]'s render as kept on the phone, or null. Reads
/// the disk only: the list's thumbnails show it, [certificatesKeptProvider]
/// and the certificate screen fill it.
final keptCertificateImageProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, ticketId) {
  return ref.watch(certificateDocumentsProvider).savedImage(ticketId);
});

/// Keeps every listed certificate's render and PDF on the phone, in the
/// background, each time the list arrives -- so one never opened opens
/// offline too, as the club designed it. Watched by the list.
final certificatesKeptProvider = Provider<void>((ref) {
  final documents = ref.watch(certificateDocumentsProvider);
  final network = ref.watch(networkStatusProvider);
  ref.listen<AsyncValue<List<Certificate>>>(certificatesProvider, (_, next) {
    final certificates = next.valueOrNull;
    if (certificates == null || certificates.isEmpty) return;
    // Nothing to ask for with no network; the list is read again, and this
    // runs again, when it is back.
    if (network.isOffline) return;
    unawaited(documents.prefetch(
      certificates,
      onKept: (id) => ref.invalidate(keptCertificateImageProvider(id)),
    ));
  }, fireImmediately: true);
});

/// How one certificate should look, from its club's template.
///
/// Falls back to the plain default rather than failing: a preview that
/// cannot be styled is still worth showing.
final certificateStyleProvider =
    FutureProvider.family<CertificateStyle, String>((ref, ticketId) async {
  try {
    return await ref
        .watch(certificateRemoteDataSourceProvider)
        .getStyle(ticketId);
  } catch (_) {
    return CertificateStyle.fallback;
  }
});

/// What checking the certificate with [code] found (`certificateCodeFrom`
/// has already made it the server's code).
final certificateVerificationProvider = FutureProvider.autoDispose
    .family<CertificateVerification, String>((ref, code) {
  return ref.watch(certificateRemoteDataSourceProvider).verify(code);
});

/// The ticket ids the user has pinned, device-local.
final pinnedCertificatesProvider =
    StateNotifierProvider<PinnedCertificatesNotifier, Set<String>>((ref) {
  return PinnedCertificatesNotifier(ref.watch(certificatePinStoreProvider));
});

class PinnedCertificatesNotifier extends StateNotifier<Set<String>> {
  final CertificatePinStore _store;

  PinnedCertificatesNotifier(this._store) : super(const <String>{}) {
    _load();
  }

  Future<void> _load() async {
    state = await _store.read();
  }

  Future<void> toggle(String ticketId) async {
    state = await _store.toggle(ticketId);
  }

  bool isPinned(String ticketId) => state.contains(ticketId);
}

/// How the list is ordered.
enum CertificateSort {
  newest('Newest first'),
  oldest('Oldest first'),
  nameAZ('Name A–Z'),
  clubAZ('Club A–Z');

  const CertificateSort(this.label);
  final String label;
}

final certificateSortProvider =
    StateProvider<CertificateSort>((ref) => CertificateSort.newest);

/// What the user has typed into the search box.
final certificateSearchProvider = StateProvider<String>((ref) => '');

/// The list as the screen should show it: searched, sorted, and optionally
/// restricted to pins.
List<Certificate> applyCertificateFilters(
  List<Certificate> all, {
  required String query,
  required CertificateSort sort,
  Set<String>? onlyPinned,
}) {
  var result = all;

  if (onlyPinned != null) {
    result = result.where((c) => onlyPinned.contains(c.ticketId)).toList();
  }

  final trimmed = query.trim().toLowerCase();
  if (trimmed.isNotEmpty) {
    // Matches the three things visible on a card, so searching for what you
    // can see works -- the event, the club, or the kind of event it was.
    result = result.where((c) {
      return c.title.toLowerCase().contains(trimmed) ||
          (c.clubName ?? '').toLowerCase().contains(trimmed) ||
          (c.eventType ?? '').toLowerCase().contains(trimmed);
    }).toList();
  }

  result = [...result];
  switch (sort) {
    case CertificateSort.newest:
      result.sort((a, b) => b.issuedOn.compareTo(a.issuedOn));
    case CertificateSort.oldest:
      result.sort((a, b) => a.issuedOn.compareTo(b.issuedOn));
    case CertificateSort.nameAZ:
      result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case CertificateSort.clubAZ:
      result.sort((a, b) =>
          (a.clubName ?? '').toLowerCase().compareTo(
              (b.clubName ?? '').toLowerCase()));
  }
  return result;
}
