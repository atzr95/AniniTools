import 'dart:io';

import 'package:aninitools/models/reporting_preferences.dart';
import 'package:aninitools/views/privacy_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final stored = <String, Object>{};
  var failWrites = false;

  setUp(() async {
    stored.clear();
    failWrites = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async {
        if (call.method == 'getAll') return Map<String, Object>.of(stored);
        if (failWrites) return false;
        final args = call.arguments as Map;
        stored[args['key'] as String] = args['value'] as Object;
        return true;
      },
    );
    await (await SharedPreferences.getInstance()).reload();
  });

  test(
    'reports require a choice, survive reload and can be withdrawn',
    () async {
      final applied = <bool>[];
      final prefs = await SharedPreferences.getInstance();
      final choice = ReportingPreferences(
        prefs,
        apply: (value) async {
          applied.add(value);
        },
      );
      await choice.initialize();
      expect(choice.enabled, isFalse);
      expect(applied, [false]);
      await choice.setEnabled(true);
      expect(choice.enabled, isTrue);
      await prefs.reload();
      final restored = ReportingPreferences(
        prefs,
        apply: (value) async {
          applied.add(value);
        },
      );
      await restored.initialize();
      expect(restored.enabled, isTrue);
      await restored.setEnabled(false);
      await prefs.reload();
      expect(prefs.getBool('optional_app_reports'), isFalse);
      expect(applied, [false, true, true, false]);
    },
  );

  test(
    'failed save restores reporting and does not invent saved consent',
    () async {
      var nativeEnabled = false;
      final choice = ReportingPreferences(
        await SharedPreferences.getInstance(),
        apply: (value) async => nativeEnabled = value,
      );
      await choice.initialize();
      failWrites = true;
      await expectLater(choice.setEnabled(true), throwsStateError);
      expect(choice.enabled, isFalse);
      expect(nativeEnabled, isFalse);
      await (await SharedPreferences.getInstance()).reload();
      expect(stored['flutter.optional_app_reports'], isNull);
    },
  );

  test(
    'native failure restores the prior choice and remains retryable',
    () async {
      var failOnce = true;
      var nativeEnabled = false;
      final choice = ReportingPreferences(
        await SharedPreferences.getInstance(),
        apply: (value) async {
          nativeEnabled = value;
          if (value && failOnce) {
            failOnce = false;
            throw PlatformException(code: 'REPORTING_FAILED');
          }
        },
      );
      await choice.initialize();
      await expectLater(
        choice.setEnabled(true),
        throwsA(isA<PlatformException>()),
      );
      expect(choice.enabled, isFalse);
      expect(nativeEnabled, isFalse);
      await choice.setEnabled(true);
      expect(choice.enabled, isTrue);
      expect(nativeEnabled, isTrue);
    },
  );

  test('startup failure still shows the saved choice', () async {
    stored['flutter.optional_app_reports'] = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final choice = ReportingPreferences(
      prefs,
      apply: (_) async => throw PlatformException(code: 'REPORTING_FAILED'),
    );
    await expectLater(choice.initialize(), throwsA(isA<PlatformException>()));
    expect(choice.enabled, isTrue);
  });

  test(
    'web and bundled policies contain the same English and Malay notices',
    () {
      // The page wraps the text in headings, paragraphs and links,
      // so compare the visible words only. Each block sits on its own line.
      String words(String text) => text
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final html = File('docs/privacy.html').readAsStringSync();
      for (final language in ['en', 'ms']) {
        final article = RegExp(
          '<article id="$language"[^>]*>(.*?)</article>',
          dotAll: true,
        ).firstMatch(html);
        expect(article, isNotNull, reason: language);
        expect(
          words(article!.group(1)!),
          words(File('assets/privacy/$language.txt').readAsStringSync()),
          reason: language,
        );
      }
    },
  );

  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('privacy choice, failed save and both notices at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final choice = ReportingPreferences(
        await SharedPreferences.getInstance(),
        apply: (_) async {},
      );
      await choice.initialize();
      await tester.runAsync(() async {
        rootBundle.evict('assets/privacy/en.txt');
        rootBundle.evict('assets/privacy/ms.txt');
        await rootBundle.loadString('assets/privacy/en.txt');
        await rootBundle.loadString('assets/privacy/ms.txt');
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PrivacyDialog(reporting: choice),
                ),
                child: const Text('Open privacy'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open privacy'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      failWrites = true;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not change'), findsOneWidget);
      expect(choice.enabled, isFalse);
      failWrites = false;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(choice.enabled, isTrue);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains('Who is responsible') ?? false),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bahasa Malaysia').last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains('Pihak yang bertanggungjawab') ?? false),
        ),
        findsOneWidget,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -10000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      expect(choice.enabled, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
