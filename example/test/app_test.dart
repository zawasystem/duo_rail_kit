import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> preview(
    WidgetTester tester, {
    Size size = const Size(951, 669),
    EdgeInsets safeArea = const EdgeInsets.only(right: 84, bottom: 34),
    HorizontalEdge? edge = HorizontalEdge.right,
    bool statusBarHidden = false,
    double textScale = 1,
    EdgeInsets viewInsets = EdgeInsets.zero,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DuoRailPreviewApp(
        size: size,
        safeArea: safeArea,
        edge: edge,
        statusBarHidden: statusBarHidden,
        textScale: textScale,
        viewInsets: viewInsets,
        textDirection: textDirection,
      ),
    );
    await tester.pumpAndSettle();
  }

  final rail = find.byKey(const ValueKey('rail-column'));
  final content = find.byKey(const ValueKey('content-scaffold'));
  final fab = find.byKey(const ValueKey('add-tap'));
  final note = find.byKey(const ValueKey('session-note'));

  void expectSingleLineLabels(WidgetTester tester, Finder navigation) {
    for (final label in ['Layout', 'State', 'About']) {
      final text = find.descendant(of: navigation, matching: find.text(label));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      expect(paragraph.maxLines, 1, reason: '$label must stay on one line');
      expect(paragraph.softWrap, isFalse);
      final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length));
      expect(boxes.map((box) => box.top).toSet().length, lessThanOrEqualTo(1));
    }
  }

  testWidgets('normal entry point uses the live environment and phone bottom navigation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DuoRailExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('LIVE LAYOUT'), findsOneWidget);
    expect(find.text('SIMULATED LAYOUT'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('1 tap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right system column occupies 84 once and moves FAB to 24 above bottom', (tester) async {
    await preview(tester);
    expect(find.text('SIMULATED LAYOUT'), findsOneWidget);
    expect(tester.getRect(rail), const Rect.fromLTWH(867, 0, 84, 669));
    expect(tester.getRect(content), const Rect.fromLTWH(0, 0, 867, 669));
    expect(tester.getBottomRight(fab).dy, 645);
    expect(tester.getBottomRight(fab).dx, 851);
    final railContext = tester.element(find.byType(NavigationRail));
    expect(MediaQuery.paddingOf(railContext), const EdgeInsets.only(top: 152, bottom: 34));
    final contentContext = tester.element(content);
    expect(MediaQuery.paddingOf(contentContext), const EdgeInsets.only(top: 16, bottom: 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('native left edge wins in a narrow Split View window without a status column', (tester) async {
    await preview(
      tester,
      size: const Size(469, 669),
      safeArea: const EdgeInsets.only(bottom: 34),
      edge: HorizontalEdge.left,
    );
    expect(tester.getRect(rail), const Rect.fromLTWH(0, 0, 84, 669));
    expect(tester.getRect(content), const Rect.fromLTWH(84, 0, 385, 669));
    expect(MediaQuery.paddingOf(tester.element(find.byType(NavigationRail))), const EdgeInsets.only(bottom: 34));
    expect(MediaQuery.paddingOf(tester.element(content)).top, 16);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden status column does not reserve the visible status band', (tester) async {
    await preview(
      tester,
      size: const Size(678, 466),
      safeArea: const EdgeInsets.only(left: 84, bottom: 21),
      edge: HorizontalEdge.left,
      statusBarHidden: true,
    );
    expect(tester.getRect(rail).width, 84);
    expect(MediaQuery.paddingOf(tester.element(find.byType(NavigationRail))), const EdgeInsets.only(bottom: 21));
    expect(tester.getBottomRight(fab).dy, 442);
    expect(tester.takeException(), isNull);
  });

  testWidgets('width fallback keeps safe area outside its 80 pixel rail', (tester) async {
    await preview(
      tester,
      size: const Size(800, 700),
      safeArea: const EdgeInsets.only(left: 24, top: 24, bottom: 20),
      edge: null,
    );
    expect(tester.getRect(rail), const Rect.fromLTWH(0, 0, 104, 700));
    expect(tester.getRect(content).left, 104);
    expect(tester.widget<Scaffold>(content).floatingActionButtonLocation, isNull);
    expect(find.text('Window width'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counter and text survive right rail, left rail, bottom bar, and tab changes', (tester) async {
    await preview(tester);
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.tap(fab);
    await tester.pumpAndSettle();
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Still here after moving the rail');
    final editableState = tester.state<EditableTextState>(find.byType(EditableText));
    await preview(
      tester,
      size: const Size(469, 669),
      safeArea: const EdgeInsets.only(bottom: 34),
      edge: HorizontalEdge.left,
    );
    expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editableState));
    expect(tester.widget<TextField>(note).controller!.text, 'Still here after moving the rail');
    expect(find.text('2 taps'), findsOneWidget);
    await preview(tester, size: const Size(390, 844), safeArea: const EdgeInsets.only(top: 47, bottom: 34), edge: null);
    expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editableState));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('2 taps'), findsOneWidget);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(note).controller!.text, 'Still here after moving the rail');
    expect(find.text('2 taps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('physical system edge stays right in an RTL preview', (tester) async {
    await preview(tester, textDirection: TextDirection.rtl);
    expect(tester.getRect(rail).left, 867);
    expect(tester.getRect(content).right, 867);
    expect(tester.getTopLeft(fab).dx, closeTo(16, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text and keyboard keep the rail scrollable without overflow', (tester) async {
    await preview(
      tester,
      size: const Size(469, 669),
      textScale: 2,
      viewInsets: const EdgeInsets.only(bottom: 280),
    );
    expect(tester.getBottomRight(fab).dy, 365);
    expect(tester.getRect(find.byType(NavigationRail)).bottom, 389);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).scrollable, isTrue);
    expect(tester.takeException(), isNull);
    final railScroll = find.descendant(of: find.byType(NavigationRail), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('About'), 120, scrollable: railScroll);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Let the system lead.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phone at large text can reach and use the note', (tester) async {
    await preview(
      tester,
      size: const Size(320, 640),
      safeArea: const EdgeInsets.only(top: 24),
      edge: null,
      textScale: 2,
    );
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Accessible note');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(note).controller!.text, 'Accessible note');
    expect(tester.takeException(), isNull);
  });

  testWidgets('rail and bottom labels stay on one line even at large text', (tester) async {
    await preview(tester, size: const Size(469, 669), textScale: 2);
    expectSingleLineLabels(tester, find.byType(NavigationRail));
    await preview(tester, size: const Size(320, 640), safeArea: EdgeInsets.zero, edge: null, textScale: 2);
    expectSingleLineLabels(tester, find.byType(NavigationBar));
    expect(tester.takeException(), isNull);
  });
}
