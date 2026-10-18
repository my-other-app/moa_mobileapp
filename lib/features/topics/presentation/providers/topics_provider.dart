import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/data/repositories/topic_repository_impl.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';

/// Every topic with its interests, from `/interests/list` -- once a
/// session (the server caches it too). The interest picker, and working out
/// an event's or club's topics when the server does not send them, read it.
///
/// A failure is the provider's error, for a screen to offer a retry
/// (`ref.invalidate`); screens that only decorate use `valueOrNull`.
final topicCatalogueProvider = FutureProvider<List<Topic>>((ref) async {
  final result = await ref.watch(topicRepositoryProvider).getCatalogue();
  return result.fold((failure) => throw failure, (topics) => topics);
});

/// Topics for browsing and filtering, with counts where the server has them.
///
/// `/interests/topics` first. A server from before topics answers 404 (and
/// any server can fail): then the catalogue, which has the same topics and
/// interests without the numbers -- read through [topicCatalogueProvider] so
/// it is not fetched twice.
final topicDirectoryProvider = FutureProvider<List<Topic>>((ref) async {
  final result = await ref.watch(topicRepositoryProvider).getDirectory();
  if (result.isRight) return result.right;
  return ref.watch(topicCatalogueProvider.future);
});

/// Every interest, in topic order, each with its topic as `categoryId`.
final allInterestsProvider = FutureProvider<List<Interest>>((ref) async {
  return interestsOf(await ref.watch(topicCatalogueProvider.future));
});
