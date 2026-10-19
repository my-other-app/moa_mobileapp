import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/saved_then_fresh.dart';
import 'package:finnet/features/topics/data/repositories/topic_repository_impl.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// Every topic with its interests, from `/interests/list` -- once a
/// session (the server caches it too). The interest picker, and working out
/// an event's or club's topics when the server does not send them, read it.
///
/// The copy saved on this phone comes first, then the server's.
///
/// A failure with nothing saved is the provider's error, for a screen to
/// offer a retry (`ref.invalidate`); screens that only decorate use
/// `valueOrNull`.
final topicCatalogueProvider = StreamProvider<List<Topic>>((ref) {
  final repository = ref.watch(topicRepositoryProvider);
  return savedThenFresh(
    saved: repository.savedCatalogue,
    fresh: () async {
      final result = await repository.getCatalogue();
      return result.fold((failure) => throw failure, (topics) => topics);
    },
  );
});

/// Topics for browsing and filtering, with counts where the server has them.
///
/// `/interests/topics` first. A server from before topics answers 404 (and
/// any server can fail): then the catalogue, which has the same topics and
/// interests without the numbers -- read through [topicCatalogueProvider] so
/// it is not fetched twice. The copy saved on this phone comes first.
final topicDirectoryProvider = StreamProvider<List<Topic>>((ref) {
  final repository = ref.watch(topicRepositoryProvider);
  return savedThenFresh(
    saved: repository.savedDirectory,
    fresh: () async {
      final result = await repository.getDirectory();
      if (result.isRight) return result.right;
      return ref.watch(topicCatalogueProvider.future);
    },
  );
});
