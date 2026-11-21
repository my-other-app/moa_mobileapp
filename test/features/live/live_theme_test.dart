import 'package:finnet/features/live/domain/live_theme.dart';
import 'package:finnet/features/live/presentation/widgets/live_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

Color hex(String h) => liveHex(h)!;

void main() {
  group('contrast, as the server computes it', () {
    test('the WCAG ratio', () {
      expect(liveContrast(Colors.white, Colors.black), closeTo(21, 0.01));
      expect(liveContrast(hex('#777777'), Colors.white), closeTo(4.48, 0.01));
      expect(liveContrast(hex('#4FCDB0'), hex('#0B0E0D')),
          greaterThan(liveGraphicContrast));
    });

    test('text on a fill: white, the ink, then black', () {
      expect(liveTextOn([hex('#DC2626')]), liveLight);
      expect(liveTextOn([hex('#D97706')]), liveDark);
      expect(liveTextOn([hex('#FFD400')]), liveDark);
      expect(liveTextOn([hex('#0B0E0D')]), liveLight);
      // Mid grey: neither white nor the ink reaches AA; black does.
      expect(liveTextOn([hex('#808080')]), liveBlack);
    });

    test('an accent too faint for a card is darkened just enough', () {
      final faint = hex('#4FCDB0');
      expect(liveContrast(faint, Colors.white), lessThan(3));
      final ok = liveEnsureContrast(faint, Colors.white, 4.5);
      expect(liveContrast(ok, Colors.white), greaterThanOrEqualTo(4.5));
      // Already readable: left alone.
      expect(liveEnsureContrast(hex('#0C7A66'), Colors.white, 3),
          hex('#0C7A66'));
      // On a dark fill it is lightened instead.
      final onDark = liveEnsureContrast(hex('#222222'), Colors.black, 3);
      expect(liveLuminance(onDark), greaterThan(liveLuminance(hex('#222222'))));
    });
  });

  group('LiveTheme', () {
    test('reads the contract\'s theme', () {
      final t = LiveTheme.fromJson(themeJson(
        display: 'bebas_neue',
        style: 'letters',
        timer: 'ring',
        logo: mediaJson(),
        guest: {
          'text_scale': 1.2,
          'logo': true,
          'background': 'theme',
          'answer_layout': 'grid'
        },
        board: {'size': 10, 'podium': false, 'animate': false, 'own_rank': false},
      ));
      expect(t.background, hex('#0B0E0D'));
      expect(t.accent, hex('#4FCDB0'));
      expect(t.answers, hasLength(6));
      expect(t.onAnswer(2), liveDark, reason: 'the server\'s text colour');
      expect(t.displayFont, 'bebas_neue');
      expect(t.answerStyle, LiveAnswerStyle.letters);
      expect(t.timer, LiveTimerStyle.ring);
      expect(t.boardSize, 10);
      expect(t.podium, isFalse);
      expect(t.animate, isFalse);
      expect(t.ownRank, isFalse);
      expect(t.logo!.forPhone, 'https://cdn.test/logo-960.webp',
          reason: 'medium on phones');
      expect(t.drawsBackground, isTrue);
      expect(t.grid, isTrue);
      expect(t.textScale, 1.2);
    });

    test('anything missing or out of range takes the default', () {
      final t = LiveTheme.fromJson({
        'colors': {'background': 'red', 'answers': ['#FFFFFF']},
        'timer': 'sundial',
        'answers': {'style': 'emoji'},
        'font': {'display': 'comic_sans'},
        'guest': {'text_scale': 3, 'background': 'video'},
        'background': {'kind': 'image', 'image': null, 'dim': 0.1},
      });
      expect(t.background, hex('#0B0E0D'));
      expect(t.answers, LiveTheme.meridianAnswers);
      expect(t.timer, LiveTimerStyle.bar);
      expect(t.answerStyle, LiveAnswerStyle.shapes);
      expect(t.displayFont, 'dm_sans');
      expect(t.textScale, 1.3, reason: 'held to what a phone takes');
      expect(t.guestBackground, 'plain');
      expect(t.backgroundKind, 'color',
          reason: 'a picture that is not there draws the colour');
      expect(t.dim, 0.3);
      expect(LiveTheme.fromJson('nope').preset, 'meridian_dark');
    });

    test('text colours the server left out are worked out the same way', () {
      final t = LiveTheme.fromJson(themeJson(
          background: '#F4F5F2', accent: '#0C7A66', text: const {}));
      expect(t.onBackground, liveDark);
      expect(t.onAccent, liveLight);
      expect(t.onAnswer(2), liveDark);
    });

    test('a gradient, and a picture, are read with their pieces', () {
      final g = LiveTheme.fromJson(themeJson(bg: {
        'kind': 'gradient',
        'gradient': {'from': '#101820', 'to': '#29335C', 'angle': 450},
        'image': null,
        'dim': 0.45,
      }));
      expect(g.backgroundKind, 'gradient');
      expect(g.gradient!.angle, 90);
      final i = LiveTheme.fromJson(themeJson(bg: {
        'kind': 'image',
        'gradient': null,
        'image': mediaJson('bg'),
        'dim': 0.6,
      }));
      expect(i.backgroundKind, 'image');
      expect(i.image!.forPhone, 'https://cdn.test/bg-960.webp');
      expect(i.dim, 0.6);
      expect(LiveMedia.fromJson({'medium': 'javascript:alert(1)'}), isNull);
    });

    test('fonts: every one the contract allows ships, DM Sans for the rest',
        () {
      expect(liveFontFamily('dm_sans'), 'DMSans');
      expect(liveFontFamily('bebas_neue'), 'BebasNeue');
      expect(liveFontFamily('poppins'), 'Poppins');
      expect(liveFontFamily('space_grotesk'), 'SpaceGrotesk');
      expect(liveFontFamily('inter'), 'Inter');
      expect(liveFontFamily('noto_sans'), 'NotoSans');
      expect(liveFontFamily('comic_sans'), 'DMSans');
      for (final f in ['dm_sans', 'bebas_neue', 'poppins', 'space_grotesk',
          'inter', 'noto_sans']) {
        expect(liveFontFamilies, contains(liveFontFamily(f)), reason: f);
      }
    });

    test('the state: custom or not, and its version', () {
      final s = LiveThemeState.fromJson(
          {'custom': true, 'theme': themeJson(), 'version': 'a91c3f02'})!;
      expect(s.custom, isTrue);
      expect(s.version, 'a91c3f02');
      final none = LiveThemeState.fromJson({'custom': false, 'theme': themeJson()})!;
      expect(none.custom, isFalse);
      expect(LiveThemeState.fromJson(null), isNull);
    });
  });

  group('LiveLook', () {
    LiveLook lookOf(Map<String, dynamic> theme, {bool custom = true}) =>
        LiveLook.from(LiveThemeState(
            custom: custom, theme: LiveTheme.fromJson(theme), version: 'v1'));

    test('no theme saved: the room exactly as it was', () {
      expect(LiveLook.from(null), same(LiveLook.standard));
      expect(lookOf(themeJson(display: 'bebas_neue'), custom: false),
          same(LiveLook.standard));
      const s = LiveLook.standard;
      expect(s.page, LiveColors.wash);
      expect(s.liveCard, LiveColors.tint);
      expect(s.accent, LiveColors.deep);
      expect(s.button, LiveColors.ink);
      expect(s.answers, LiveColors.answers);
      expect(s.onAnswer(2), Colors.white, reason: 'today\'s white text');
      expect(s.timer, LiveTimerStyle.ring, reason: 'today\'s clock');
      expect(s.displayFamily, isNull);
      expect(s.textScale, 1.0);
      expect(s.logo, isNull);
    });

    test('a theme on a phone: readable accent, its answers and choices', () {
      final look = lookOf(themeJson(
        display: 'bebas_neue',
        style: 'letters',
        timer: 'number',
        logo: mediaJson(),
      ));
      expect(look.custom, isTrue);
      expect(look.page, LiveColors.wash, reason: 'guest background: plain');
      expect(look.drawsPage, isFalse);
      expect(liveContrast(look.accent, look.liveCard),
          greaterThanOrEqualTo(liveTextContrast));
      expect(liveContrast(look.dot, look.liveCard),
          greaterThanOrEqualTo(liveGraphicContrast));
      expect(liveContrast(look.onButton, look.button),
          greaterThanOrEqualTo(liveTextContrast));
      expect(look.answerColour(1), hex('#2563EB'));
      expect(look.onAnswer(2), liveDark);
      expect(look.mark(0), 'A');
      expect(look.timer, LiveTimerStyle.number);
      expect(look.displayFamily, 'BebasNeue');
      expect(look.display(const TextStyle(fontSize: 20)).fontFamily,
          'BebasNeue');
      expect(look.logo, 'https://cdn.test/logo-960.webp');
    });

    test('the page drawn from the theme, its text the server\'s', () {
      final look = lookOf(themeJson(guest: {
        'text_scale': 1.0,
        'logo': false,
        'background': 'theme',
        'answer_layout': 'column'
      }, logo: mediaJson()));
      expect(look.drawsPage, isTrue);
      expect(look.page, hex('#0B0E0D'));
      expect(look.onPage, liveLight);
      expect(look.bar, hex('#0B0E0D'));
      expect(look.onBar, liveLight);
      expect(look.logo, isNull, reason: 'guest.logo off');
    });

    test('marks: shapes, letters, or none in a plain list', () {
      expect(lookOf(themeJson()).mark(4), '★');
      expect(lookOf(themeJson(style: 'plain')).mark(0), isNull);
    });

    test('a gradient\'s CSS angle as where it starts and ends', () {
      final (b0, e0) = LiveBackdrop.ends(0);
      expect(b0.y, closeTo(1, 1e-9), reason: '0: to the top');
      expect(e0.y, closeTo(-1, 1e-9));
      final (b90, e90) = LiveBackdrop.ends(90);
      expect(b90.x, closeTo(-1, 1e-9), reason: '90: to the right');
      expect(e90.x, closeTo(1, 1e-9));
    });

    test('the phone\'s own text size is kept, times the theme\'s', () {
      const scaler = LiveTextScaler(TextScaler.linear(2), 1.2);
      expect(scaler.scale(10), closeTo(24, 1e-9));
      expect(scaler, const LiveTextScaler(TextScaler.linear(2), 1.2));
    });
  });
}
