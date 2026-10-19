import 'package:cached_network_image/cached_network_image.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

const _bucket = 'https://moa-media.s3.ap-south-1.amazonaws.com/clubs/logos';

/// A presigned URL as the API sends it: a fresh signature each call.
String _signed(String file, [String signature = 'abc123']) =>
    '$_bucket/$file?X-Amz-Algorithm=AWS4-HMAC-SHA256'
    '&X-Amz-Credential=AKIA%2F20261019%2Fap-south-1%2Fs3%2Faws4_request'
    '&X-Amz-Date=20261019T101500Z&X-Amz-Expires=3600'
    '&X-Amz-SignedHeaders=host&X-Amz-Signature=$signature';

/// Stands in for a disk cache, so nothing reaches a platform channel.
class _FakeCacheManager extends Fake implements BaseCacheManager {
  int emptied = 0;

  @override
  Future<void> emptyCache() async => emptied++;
}

void main() {
  group('imageCacheKey', () {
    test('a re-signed S3 link keeps its key', () {
      final today = _signed('v-1.large.jpeg', 'aaa');
      final tomorrow = _signed('v-1.large.jpeg', 'bbb');
      expect(imageCacheKey(today), '$_bucket/v-1.large.jpeg');
      expect(imageCacheKey(today), imageCacheKey(tomorrow));
    });

    test('different pictures and sizes keep different keys', () {
      expect(imageCacheKey(_signed('v-1.large.jpeg')),
          isNot(imageCacheKey(_signed('v-1.medium.jpeg'))));
      expect(imageCacheKey(_signed('v-1.large.jpeg')),
          isNot(imageCacheKey(_signed('v-2.large.jpeg'))));
    });

    test('a media CDN address is its path, whatever its query', () {
      const url = 'https://media.myotherapp.in/clubs/logos/v-1.large.jpeg';
      expect(imageCacheKey(url), url);
      expect(imageCacheKey('$url?w=400'), url);
      expect(imageCacheKey('$url#x'), url);
      expect(imageCacheKey('https://MEDIA.myotherapp.in/clubs/logos/a.png?v=2'),
          'https://media.myotherapp.in/clubs/logos/a.png');
    });

    test('the same picture from S3 and from the CDN may differ; each is stable',
        () {
      // The key follows the address the API hands out; when the backend
      // switches to the CDN, a picture is fetched once more, then cached.
      expect(imageCacheKey(_signed('v-1.large.jpeg', 'a')),
          imageCacheKey(_signed('v-1.large.jpeg', 'b')));
    });

    test('a query that names the picture is kept, in a fixed order', () {
      expect(
        imageCacheKey('https://avatars.example/png?seed=ana&size=96'),
        imageCacheKey('https://avatars.example/png?size=96&seed=ana'),
      );
      expect(
        imageCacheKey('https://avatars.example/png?seed=ana'),
        isNot(imageCacheKey('https://avatars.example/png?seed=bob')),
      );
    });

    test('CloudFront and older S3 signatures are dropped too', () {
      expect(
        imageCacheKey('https://d1.cloudfront.net/a.jpg?Expires=1&Signature=x'
            '&Key-Pair-Id=K'),
        'https://d1.cloudfront.net/a.jpg',
      );
      expect(
        imageCacheKey('https://b.s3.amazonaws.com/a.jpg?AWSAccessKeyId=A'
            '&Expires=1&Signature=s&response-content-type=image%2Fjpeg'),
        'https://b.s3.amazonaws.com/a.jpg?response-content-type=image%2Fjpeg',
      );
    });

    test('a URL without a query is its own key; a fragment is dropped', () {
      expect(imageCacheKey('$_bucket/x.jpeg'), '$_bucket/x.jpeg');
      expect(imageCacheKey('$_bucket/x.jpeg#top'), '$_bucket/x.jpeg');
    });

    test('something that is not a URL still gets a key', () {
      expect(imageCacheKey('logo.png?x=1'), 'logo.png');
    });
  });

  group('isWebImageUrl', () {
    test('only http(s) with a host', () {
      expect(isWebImageUrl('https://a.b/c.png'), isTrue);
      expect(isWebImageUrl('http://a.b/c.png'), isTrue);
      expect(isWebImageUrl(null), isFalse);
      expect(isWebImageUrl('  '), isFalse);
      expect(isWebImageUrl('/media/c.png'), isFalse);
      expect(isWebImageUrl('file:///c.png'), isFalse);
    });
  });

  group('decodeWidthFor', () {
    test('the larger side at the screen density', () {
      expect(decodeWidthFor(48, 48, 3), 144);
      expect(decodeWidthFor(360, 200, 2), 720);
      expect(decodeWidthFor(100, 300, 2), 600);
    });

    test('one known side is enough; none is null', () {
      expect(decodeWidthFor(null, 40, 3), 120);
      expect(decodeWidthFor(null, null, 3), isNull);
      expect(decodeWidthFor(double.infinity, null, 3), isNull);
    });

    test('never above the cap', () {
      expect(decodeWidthFor(4000, 10, 3), maxDecodePixels);
    });
  });

  group('overBudget', () {
    final now = DateTime(2026, 10, 19);
    final files = [
      (name: 'old', bytes: 50, used: now.subtract(const Duration(days: 9))),
      (name: 'new', bytes: 50, used: now),
      (name: 'never', bytes: 30, used: null),
      (name: 'mid', bytes: 40, used: now.subtract(const Duration(days: 2))),
    ];

    List<String> evict(int max) => overBudget(
          files,
          maxBytes: max,
          size: (f) => f.bytes,
          lastUsed: (f) => f.used,
        ).map((f) => f.name).toList();

    test('nothing goes while under the cap', () {
      expect(evict(170), isEmpty);
      expect(evict(1000), isEmpty);
    });

    test('the least recently shown go first, only as many as needed', () {
      expect(evict(140), ['never']);
      expect(evict(100), ['never', 'old']);
      expect(evict(50), ['never', 'old', 'mid']);
    });
  });

  group('AppNetworkImage', () {
    late _FakeCacheManager public;
    late _FakeCacheManager private;

    setUp(() {
      public = _FakeCacheManager();
      private = _FakeCacheManager();
      AppImageCaches.debugOverride(public: public, private: private);
    });
    tearDown(() => AppImageCaches.debugOverride());

    Widget host(Widget child) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3, size: Size(400, 800)),
            child: Scaffold(body: Center(child: child)),
          ),
        );

    testWidgets('caches by the stable key, decoded at the size drawn',
        (tester) async {
      final url = _signed('v-1.thumbnail.png');
      await tester.pumpWidget(host(AppNetworkImage(url: url, width: 48, height: 48)));

      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.imageUrl, url);
      expect(image.cacheKey, '$_bucket/v-1.thumbnail.png');
      expect(image.cacheManager, same(public));
      expect(image.memCacheWidth, 144);
    });

    testWidgets('a private picture goes to the private cache', (tester) async {
      await tester.pumpWidget(host(AppNetworkImage(
        url: _signed('me.png'),
        width: 60,
        height: 60,
        privacy: ImagePrivacy.private,
      )));

      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.cacheManager, same(private));
    });

    testWidgets('without a box, it decodes no wider than the screen',
        (tester) async {
      await tester.pumpWidget(host(AppNetworkImage(url: _signed('a.png'))));

      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.memCacheWidth, 1200);
    });

    testWidgets('no URL draws the fallback and fetches nothing', (tester) async {
      await tester.pumpWidget(host(const AppNetworkImage(url: null, width: 40, height: 40)));
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byKey(AppNetworkImage.fallbackKey), findsOneWidget);

      await tester.pumpWidget(host(AppNetworkImage(
        url: 'media/x.png',
        width: 40,
        height: 40,
        errorWidget: (_) => const Text('NO LOGO'),
      )));
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('NO LOGO'), findsOneWidget);
    });

    testWidgets('the loading and failed states are the given widgets',
        (tester) async {
      await tester.pumpWidget(host(AppNetworkImage(
        url: _signed('a.png'),
        width: 40,
        height: 40,
        placeholder: (_) => const Text('LOADING'),
        errorWidget: (_) => const Text('FAILED'),
      )));
      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

      await tester.pumpWidget(host(Builder(
        builder: (context) => image.placeholder!(context, image.imageUrl),
      )));
      expect(find.text('LOADING'), findsOneWidget);

      await tester.pumpWidget(host(Builder(
        builder: (context) =>
            image.errorWidget!(context, image.imageUrl, Exception('403')),
      )));
      expect(find.text('FAILED'), findsOneWidget);
    });

    testWidgets('ClubLogo goes through it', (tester) async {
      await tester.pumpWidget(host(ClubLogo(url: _signed('club.png'), size: 40)));

      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.cacheKey, '$_bucket/club.png');
      expect(image.memCacheWidth, 120);
    });

    test('appImageProvider keys the provider the same way, resized', () {
      final provider = appImageProvider(_signed('a.png'), decodeWidth: 96);
      expect(provider, isA<ResizeImage>());
      final inner = (provider as ResizeImage).imageProvider
          as CachedNetworkImageProvider;
      expect(inner.cacheKey, '$_bucket/a.png');
      expect(inner.cacheManager, same(public));
      expect(provider.width, 96);

      final private_ = appImageProvider(_signed('b.png'),
          privacy: ImagePrivacy.private) as CachedNetworkImageProvider;
      expect(private_.cacheManager, same(private));
    });

    test('clearing the private cache leaves the public one', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await AppImageCaches.clearPrivate();
      expect(private.emptied, 1);
      expect(public.emptied, 0);
    });
  });
}
