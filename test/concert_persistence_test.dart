import 'package:aninitools/views/flashlight/concert_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final stored = <String, Object>{};
  var failWrites = false;
  var throwWrites = false;
  int? writesBeforeInterruption;
  var writeCount = 0;

  setUp(() async {
    stored.clear();
    failWrites = throwWrites = false;
    writesBeforeInterruption = null;
    writeCount = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async {
        if (call.method == 'getAll') return Map<String, Object>.of(stored);
        if (writesBeforeInterruption != null &&
            writeCount++ >= writesBeforeInterruption!) {
          return false;
        }
        if (throwWrites) throw PlatformException(code: 'WRITE_FAILED');
        if (failWrites) return false;
        final arguments = call.arguments as Map;
        stored[arguments['key'] as String] = arguments['value'] as Object;
        return true;
      },
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (_) async => null,
    );
    await (await SharedPreferences.getInstance()).reload();
  });

  Future<void> openTemplates(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ConcertModeScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Templates'));
    await tester.tap(find.text('Templates'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> toggleFavorite(WidgetTester tester, String tooltip) async {
    tester
        .widget<IconButton>(
          find
              .byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == tooltip,
              )
              .first,
        )
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('failed favorite save keeps saved state and allows retry', (
    tester,
  ) async {
    await openTemplates(tester);
    failWrites = true;
    await toggleFavorite(tester, 'Add favorite');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Favorites'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('concert_favorites'), isNull);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    failWrites = false;
    await toggleFavorite(tester, 'Add favorite');
    expect(find.text('Favorites'), findsOneWidget);
    await prefs.reload();
    expect(prefs.getStringList('concert_favorites'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('failed removal preserves the favorite after a thrown write', (
    tester,
  ) async {
    await openTemplates(tester);
    await toggleFavorite(tester, 'Add favorite');
    throwWrites = true;
    await toggleFavorite(tester, 'Remove favorite');
    expect(find.byType(AlertDialog), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('concert_favorites'), hasLength(1));
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    throwWrites = false;
    await toggleFavorite(tester, 'Remove favorite');
    expect(find.text('Favorites'), findsNothing);
    await prefs.reload();
    expect(prefs.getStringList('concert_favorites'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('failed settings save shows an error and can be retried', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConcertModeScreen()));
    await tester.pump(const Duration(seconds: 1));
    failWrites = true;
    tester.widget<TextField>(find.byType(TextField).first).onSubmitted!('NEW');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('concert_message'), isNull);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    failWrites = false;
    tester.widget<TextField>(find.byType(TextField).first).onSubmitted!('NEW');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await prefs.reload();
    expect(prefs.getString('concert_message'), 'NEW');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('two favorite taps before a redraw keep both items', (
    tester,
  ) async {
    await openTemplates(tester);
    final buttons = tester
        .widgetList<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Add favorite',
          ),
        )
        .toList();
    buttons[0].onPressed!();
    buttons[1].onPressed!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getStringList('concert_favorites'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('partly saved settings remain readable after restart', (
    tester,
  ) async {
    // Stop at every boundary in the existing 22-key settings save.
    for (var cut = 0; cut <= 22; cut++) {
      stored.clear();
      writeCount = 0;
      writesBeforeInterruption = cut;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      await tester.pumpWidget(const MaterialApp(home: ConcertModeScreen()));
      await tester.pump(const Duration(seconds: 1));
      tester.widget<TextField>(find.byType(TextField).first).onSubmitted!(
        'NEW',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'save boundary $cut');
      if (find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK'));
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      writesBeforeInterruption = null;
      await prefs.reload();
      await tester.pumpWidget(const MaterialApp(home: ConcertModeScreen()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'restart boundary $cut');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        cut == 0 ? 'I ❤️ MUSIC' : 'NEW',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
