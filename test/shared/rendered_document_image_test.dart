import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:finnet/shared/widgets/certificate_list_card.dart';
import 'package:finnet/shared/widgets/rendered_document_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [width] x [height] PNG.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF17A58F),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  group('RenderedDocumentImage', () {
    testWidgets('takes the render\'s own shape once it is in, not a fixed one',
        (tester) async {
      // A tall layered design, nothing like the classic 800 x 519.
      final bytes = (await tester.runAsync(() => _png(300, 400)))!;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: RenderedDocumentImage(
              url: 'https://api.test/events/certificates/MOA-1/image',
              image: MemoryImage(bytes),
              placeholder: const Text('drawn'),
            ),
          ),
        ),
      ));

      // While it loads: the drawn stand-in, at the classic shape.
      expect(find.text('drawn'), findsOneWidget);

      final context = tester.element(find.text('drawn'));
      await tester.runAsync(() => precacheImage(
          RenderedDocumentImage.sizedFor(context, MemoryImage(bytes)),
          context));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(RenderedDocumentImage.imageKey), findsOneWidget);
      expect(find.text('drawn'), findsNothing);
      final ratio = tester
          .widget<AspectRatio>(find.ancestor(
            of: find.byKey(RenderedDocumentImage.imageKey),
            matching: find.byType(AspectRatio),
          ))
          .aspectRatio;
      expect(ratio, closeTo(300 / 400, 0.001));
    });

    testWidgets(
        'a print-size render is decoded at the screen\'s width, keeping its '
        'shape', (tester) async {
      // An A4 page at 150 dpi: wider than any phone draws it.
      final bytes = (await tester.runAsync(() => _png(1240, 1754)))!;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: RenderedDocumentImage(
            url: 'https://api.test/events/certificates/MOA-1/image',
            image: MemoryImage(bytes),
            placeholder: const Text('drawn'),
          ),
        ),
      ));
      final context = tester.element(find.text('drawn'));
      final sized = RenderedDocumentImage.sizedFor(context, MemoryImage(bytes));
      await tester.runAsync(() => precacheImage(sized, context));
      await tester.pump();
      await tester.pump();

      final shown =
          tester.widget<Image>(find.byKey(RenderedDocumentImage.imageKey));
      final media =
          MediaQuery.of(tester.element(find.byKey(RenderedDocumentImage.imageKey)));
      expect(shown.image, isA<ResizeImage>());
      expect((shown.image as ResizeImage).width,
          (media.size.width * media.devicePixelRatio).ceil().clamp(0, 2048));
      final ratio = tester
          .widget<AspectRatio>(find.ancestor(
            of: find.byKey(RenderedDocumentImage.imageKey),
            matching: find.byType(AspectRatio),
          ))
          .aspectRatio;
      expect(ratio, closeTo(1240 / 1754, 0.01));
    });

    testWidgets('no address: the stand-in, for good', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: RenderedDocumentImage(url: '', placeholder: Text('drawn')),
      ));
      expect(find.text('drawn'), findsOneWidget);
      expect(find.byKey(RenderedDocumentImage.imageKey), findsNothing);
    });
  });

  testWidgets('the certificates list gives the render a landscape slot',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CertificateListCard(
          title: 'Hack Night Certificate',
          organization: 'Tinkerhub',
          type: 'Tech',
          date: '1 Dec 2026',
          imageUrl: '',
          leadingWidth: CertificateListCard.documentWidth,
          leading: SizedBox.expand(key: ValueKey('render')),
        ),
      ),
    ));
    final size = tester.getSize(find.byKey(const ValueKey('render')));
    expect(size.width, CertificateListCard.documentWidth);
    expect(size.height, 48);
    expect(size.width / size.height, closeTo(800 / 519, 0.05));
  });
}
