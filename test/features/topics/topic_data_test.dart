import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/topics/data/datasources/topic_remote_datasource.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show RouteAdapter;
import 'topic_fixtures.dart';

void main() {
  late RouteAdapter api;
  late ProviderContainer container;

  setUp(() {
    api = RouteAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = api
      ..interceptors.add(ErrorInterceptor());
    container = ProviderContainer(overrides: [
      topicRemoteDataSourceProvider
          .overrideWithValue(TopicRemoteDataSourceImpl(dio)),
    ]);
  });

  tearDown(() => container.dispose());

  group('the catalogue', () {
    test('is /interests/list, read as topics', () async {
      api.on('GET', '/interests/list', contractListBody);

      final topics = await container.read(topicCatalogueProvider.future);

      expect(api.requests.single.path, '/interests/list');
      expect(topics.map((t) => t.slug), ['development', 'arts', 'community']);
    });

    test('is fetched once however many screens read it', () async {
      api.on('GET', '/interests/list', contractListBody);

      await container.read(topicCatalogueProvider.future);
      await container.read(topicCatalogueProvider.future);
      await container.read(topicDirectoryProvider.future); // its fallback

      expect(api.sent('GET', '/interests/list'), hasLength(1));
    });

    test('a failure is an error, for the screen to offer a retry', () async {
      api.on('GET', '/interests/list', {'message': 'down'}, status: 503);

      await expectLater(
          container.read(topicCatalogueProvider.future), throwsA(anything));
    });

    test('every interest, flattened, knows its topic', () async {
      api.on('GET', '/interests/list', productionListBody);

      final interests =
          interestsOf(await container.read(topicCatalogueProvider.future));

      expect(interests.map((i) => i.name),
          ['Coding', 'UI/UX', 'Photography', 'Music']);
      expect(interests.map((i) => i.categoryId).toSet(), {1});
    });
  });

  group('the directory', () {
    test('is /interests/topics, with counts, when the server has it',
        () async {
      api.on('GET', '/interests/topics', contractTopicsBody);

      final topics = await container.read(topicDirectoryProvider.future);

      expect(topics.first.upcomingEvents, 12);
      expect(api.sent('GET', '/interests/list'), isEmpty);
    });

    test('falls back to /interests/list on a server without it (404)',
        () async {
      // Production today: no route, so the RouteAdapter answers 404.
      api.on('GET', '/interests/list', productionListBody);

      final topics = await container.read(topicDirectoryProvider.future);

      expect(api.sent('GET', '/interests/topics'), hasLength(1));
      expect(topics.single.name, 'arts');
      expect(topics.single.upcomingEvents, isNull);
    });

    for (final status in [405, 422]) {
      test('falls back on $status too (production answers 405 today)',
          () async {
        api
          ..on('GET', '/interests/topics', {'detail': 'Method Not Allowed'},
              status: status)
          ..on('GET', '/interests/list', productionListBody);

        final topics = await container.read(topicDirectoryProvider.future);

        expect(api.sent('GET', '/interests/topics'), hasLength(1));
        expect(topics.single.name, 'arts');
      });
    }

    test('the fallback shares the catalogue rather than fetching it again',
        () async {
      api.on('GET', '/interests/list', productionListBody);

      await container.read(topicCatalogueProvider.future);
      await container.read(topicDirectoryProvider.future);

      expect(api.sent('GET', '/interests/list'), hasLength(1));
    });

    test('when both fail it is an error', () async {
      await expectLater(
          container.read(topicDirectoryProvider.future), throwsA(anything));
    });
  });
}
