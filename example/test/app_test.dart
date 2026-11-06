import 'dart:math' as math;

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The iPhone Duo inner portrait band beside the status display. Recorded on the iOS 27.2 Simulator.
const TopBarRegion _innerPortraitBand = TopBarRegion(
  rect: Rect.fromLTRB(16, 24, 525, 72),
  safeTop: 82,
  viewSize: Size(669, 951),
);

/// The item region of the inner landscape vertical bar column. Recorded on the iOS 27.2 Simulator.
const Rect _innerLandscapeItems = Rect.fromLTRB(879, 124, 927, 635);

/// The top of the top bar region in a UIKit window. Recorded on the iOS 27.2 Simulator.
const double _topBarTop = 24;

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
    TopBarRegion? topBar,
    VerticalBarRegion? verticalBar,
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
        topBar: topBar,
        verticalBar: verticalBar,
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
    // Without native values, both region readouts show none.
    expect(find.text('None'), findsNWidgets(2));
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('1 tap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right system rail occupies 96 over the 84 column and moves FAB to 24 above bottom', (tester) async {
    await preview(tester);
    expect(find.text('SIMULATED LAYOUT'), findsOneWidget);
    expect(tester.getRect(rail), const Rect.fromLTWH(855, 0, 96, 669));
    expect(tester.getRect(content), const Rect.fromLTWH(0, 0, 855, 669));
    expect(tester.getBottomRight(fab).dy, 645);
    expect(tester.getBottomRight(fab).dx, 839);
    final railContext = tester.element(find.byType(NavigationRail));
    expect(MediaQuery.paddingOf(railContext), const EdgeInsets.only(top: 152, bottom: 34));
    final contentContext = tester.element(content);
    expect(MediaQuery.paddingOf(contentContext), const EdgeInsets.only(top: 16, bottom: 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('metrics show the top band and vertical bar regions that match the window', (tester) async {
    // The inner portrait window of [_innerPortraitBand].
    await preview(
      tester,
      size: const Size(669, 951),
      safeArea: const EdgeInsets.only(top: 82, bottom: 34),
      edge: null,
      topBar: _innerPortraitBand,
    );
    expect(find.text('TOP BAR REGION'), findsOneWidget);
    expect(find.text('509 × 48 px'), findsOneWidget);
    expect(find.text('x 16–525, y 24–72 · safe top 82'), findsOneWidget);
    expect(find.text('No vertical bar region'), findsOneWidget);

    // Inner landscape: the right column's item region, and no top band.
    await preview(
      tester,
      verticalBar: const VerticalBarRegion(
        rect: _innerLandscapeItems,
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
      ),
    );
    expect(find.text('48 × 511 px'), findsOneWidget);
    expect(find.text('Right edge · x 879–927, y 124–635'), findsOneWidget);
    expect(find.text('No band beside the status bar'), findsOneWidget);

    // A sample from another window size is stale and is not shown.
    await preview(
      tester,
      verticalBar: const VerticalBarRegion(
        rect: _innerLandscapeItems,
        edge: HorizontalEdge.right,
        viewSize: Size(669, 951),
      ),
    );
    expect(find.text('No vertical bar region'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar row moves into the top band beside the status display and keeps state', (tester) async {
    const size = Size(669, 951);
    const safeArea = EdgeInsets.only(top: 82, bottom: 34);
    final appBar = find.byType(AppBar);
    final toolbar = find.byType(NavigationToolbar);
    final reset = find.byKey(const ValueKey('reset-taps'));
    final contentScroll = find
        .descendant(of: find.byKey(const ValueKey('content-scroll')), matching: find.byType(Scrollable))
        .first;

    // Before a band arrives, the toolbar sits below the 82-point safe area, right of the 80-point width rail.
    await preview(tester, size: size, safeArea: safeArea, edge: null);
    expect(tester.getRect(rail), const Rect.fromLTWH(0, 0, 80, 951));
    expect(tester.getRect(appBar), const Rect.fromLTRB(80, 0, 669, 138));
    expect(tester.getRect(toolbar), const Rect.fromLTRB(80, 82, 669, 138));
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('1 tap'), findsOneWidget);
    final contentState = tester.state(contentScroll);
    final barState = tester.state(appBar);
    final resetFocus = Focus.of(tester.element(find.descendant(of: reset, matching: find.byType(Icon))))
      ..requestFocus();
    await tester.pump();

    // With the band, the row fills the band's part of the pane and the content starts at the safe area.
    await preview(tester, size: size, safeArea: safeArea, edge: null, topBar: _innerPortraitBand);
    expect(tester.getRect(appBar), const Rect.fromLTRB(80, 0, 669, 82));
    expect(tester.getRect(toolbar), const Rect.fromLTRB(80, 24, 525, 72));
    expect(tester.getRect(find.byKey(const ValueKey('content-scroll'))).top, 82);
    expect(tester.getRect(reset).bottom, lessThanOrEqualTo(72));
    expect(tester.getRect(reset).right, lessThanOrEqualTo(525));
    // The page, its counter, the app bar and the focused action survive the switch, and controls in the band respond.
    expect(tester.state(contentScroll), same(contentState));
    expect(tester.state(appBar), same(barState));
    expect(resetFocus.hasPrimaryFocus, isTrue);
    expect(find.text('1 tap'), findsOneWidget);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('0 taps'), findsOneWidget);
    // Root safe areas are unchanged for everything else.
    expect(MediaQuery.paddingOf(tester.element(content)).top, 82);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metric cards use up to three columns of at least 220 points each', (tester) async {
    Rect card(String title) =>
        tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(SizedBox)).first);

    // Inner landscape: three columns. (Whether the hero leaves room for the second row depends on the platform font,
    // so it is checked on the Simulator rather than with the test font.)
    await preview(tester);
    expect(card('PLACEMENT').width, closeTo((855 - 40 - 24) / 3, 0.001));

    // Inner portrait beside the 80-point width rail: two columns rather than three narrow ones.
    await preview(tester, size: const Size(669, 951), safeArea: const EdgeInsets.only(top: 82, bottom: 34), edge: null);
    expect(card('PLACEMENT').width, closeTo((589 - 40 - 12) / 2, 0.001));

    // The 220-point boundary beside an 80-point rail: 684 points of content fit three columns, 683 only two.
    await preview(tester, size: const Size(804, 700), safeArea: EdgeInsets.zero, edge: null);
    expect(card('PLACEMENT').width, closeTo(220, 0.001));
    await preview(tester, size: const Size(803, 700), safeArea: EdgeInsets.zero, edge: null);
    expect(card('PLACEMENT').width, closeTo((683 - 12) / 2, 0.001));

    // Wide content (capped at 1060) still uses at most three columns.
    await preview(
      tester,
      size: const Size(1180, 820),
      safeArea: const EdgeInsets.only(top: 24, bottom: 20),
      edge: null,
    );
    expect(card('PLACEMENT').width, closeTo((1060 - 24) / 3, 0.001));

    // Narrow panes and 1.5x text keep one column.
    await preview(
      tester,
      size: const Size(469, 669),
      safeArea: const EdgeInsets.only(bottom: 34),
      edge: HorizontalEdge.left,
    );
    expect(card('PLACEMENT').width, closeTo(373 - 40, 0.001));
    await preview(tester, textScale: 1.5);
    expect(card('PLACEMENT').width, closeTo(855 - 40, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide hero uses one line only where the title fits', (tester) async {
    final sketch = find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 200);
    String title() => tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere((data) => data.startsWith('At home'));

    // The test font is too wide for one line here, so the forced breaks and the taller sketch stay.
    await preview(tester);
    expect(title(), 'At home\non every edge.');
    expect(tester.getSize(sketch).height, 158);

    // At half-size text the title fits: one line and the shorter sketch.
    await preview(tester, textScale: 0.5);
    expect(title(), 'At home on every edge.');
    expect(tester.getSize(sketch).height, 104);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native left edge wins in a narrow Split View window without a status column', (tester) async {
    await preview(
      tester,
      size: const Size(469, 669),
      safeArea: const EdgeInsets.only(bottom: 34),
      edge: HorizontalEdge.left,
    );
    expect(tester.getRect(rail), const Rect.fromLTWH(0, 0, 96, 669));
    expect(tester.getRect(content), const Rect.fromLTWH(96, 0, 373, 669));
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
    expect(tester.getRect(rail).width, 96);
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
    expect(tester.getRect(rail).left, 855);
    expect(tester.getRect(content).right, 855);
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

  testWidgets('content paints past the safe area while reveals stay inside it', (tester) async {
    final scroll = find.byKey(const ValueKey('content-scroll'));

    // Beside a system rail the viewport starts below the app bar (16 added at the top plus the 56 toolbar) and ends at
    // the bottom safe area (34). The content is painted past the bottom, so the list is not clipped above the home
    // indicator; at the top it passes under the opaque app bar.
    await preview(tester);
    expect(tester.getRect(scroll), const Rect.fromLTRB(0, 72, 855, 635));
    expect(tester.widget<SingleChildScrollView>(scroll).clipBehavior, Clip.none);
    expect(tester.widget<SingleChildScrollView>(scroll).padding, const EdgeInsets.fromLTRB(20, 20, 20, 100));

    // A note revealed from under the app bar below a 62-point status bar lands below the bar, not behind it.
    await preview(tester, size: const Size(402, 874), safeArea: const EdgeInsets.only(top: 62, bottom: 34), edge: null);
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppBar)), const Rect.fromLTRB(0, 0, 402, 118));
    final position = tester
        .state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first)
        .position;
    await tester.ensureVisible(note);
    await tester.pumpAndSettle();
    position.jumpTo(position.pixels + tester.getTopLeft(note).dy - 100);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(note).dy, 100);
    await tester.tapAt(tester.getBottomLeft(note) + const Offset(40, -12));
    await tester.pumpAndSettle();
    final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
    final caret = MatrixUtils.transformRect(
      editable.getTransformTo(null),
      editable.getLocalRectForCaret(const TextPosition(offset: 0)),
    );
    expect(caret.top, greaterThanOrEqualTo(118));
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

  const innerLandscapeBar = VerticalBarRegion(
    rect: _innerLandscapeItems,
    edge: HorizontalEdge.right,
    viewSize: Size(951, 669),
    topBarTop: _topBarTop,
  );
  // The Split View windows on iPhone Duo. Recorded on the iOS 27.2 Simulator.
  const splitView = Size(469, 669);
  const rightWindowBar = VerticalBarRegion(
    rect: Rect.fromLTRB(397, 124, 445, 635),
    edge: HorizontalEdge.right,
    viewSize: splitView,
    topBarTop: _topBarTop,
  );
  const leftWindowBar = VerticalBarRegion(
    rect: Rect.fromLTRB(24, 16, 72, 635),
    edge: HorizontalEdge.left,
    viewSize: splitView,
    topBarTop: _topBarTop,
  );

  group('detail page', () {
    const innerLandscapeActions = ['Share', 'Favorite', 'Manage'];

    final openDetail = find.byKey(const ValueKey('open-detail'));
    final detailTaps = find.byKey(const ValueKey('detail-taps'));
    final lastAction = find.byKey(const ValueKey('last-action'));
    final moreActions = find.byKey(const ValueKey('more-actions'));
    Finder inAppBar(Finder finder) => find.descendant(of: find.byType(AppBar), matching: finder);
    String textOf(WidgetTester tester, Finder finder) => tester.widget<Text>(finder).data!;

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    /// Back and the actions are in the app bar, and only there: no column cell draws them as well.
    void expectAppBarControls(WidgetTester tester) {
      expect(inAppBar(find.byType(BackButton)), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      for (final label in innerLandscapeActions) {
        expect(inAppBar(find.byTooltip(label)), findsOneWidget, reason: label);
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
    }

    testWidgets('opens from Overview and draws back and actions in the inner landscape column', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      await tapVisible(tester, openDetail);
      expect(find.text('Detail'), findsOneWidget);

      // UIKit's positions: back y 124-172, then the actions from y 184, 52 apart.
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(879, 124, 927, 172));
      for (final (index, label) in innerLandscapeActions.indexed) {
        expect(tester.getRect(find.byTooltip(label)), Rect.fromLTWH(879, 184 + 52.0 * index, 48, 48), reason: label);
      }
      // The app bar keeps only the title.
      expect(inAppBar(find.byType(BackButton)), findsNothing);
      expect(inAppBar(find.byType(IconButton)), findsNothing);
      expect(inAppBar(find.text('Detail')), findsOneWidget);

      // Share reports its cell as the anchor; Favorite is a toggle; Manage opens a menu with a destructive Delete.
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(textOf(tester, lastAction), 'Share from x 879–927, y 184–232');
      final favorite = find.descendant(of: find.byTooltip('Favorite'), matching: find.byType(IconButton));
      expect(tester.widget<IconButton>(favorite).isSelected, isFalse);
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(favorite).isSelected, isTrue);
      await tester.tap(find.byTooltip('Manage'));
      await tester.pumpAndSettle();
      final delete = find.descendant(of: find.text('Delete'), matching: find.byType(RichText));
      expect(tester.widget<RichText>(delete).text.style?.color, Theme.of(tester.element(delete)).colorScheme.error);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete chosen. The example deletes nothing.'), findsOneWidget);

      // Back pops the page.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keeps the title at the leading edge on iOS while the column holds the actions',
      (tester) async {
        AppBar detailAppBar() => tester.widget<AppBar>(find.byType(AppBar));

        // UIKit leaves the title at the leading edge; an iOS AppBar centres a title with fewer than two actions.
        await preview(tester, verticalBar: innerLandscapeBar);
        await tapVisible(tester, openDetail);
        expect(detailAppBar().centerTitle, isFalse);
        expect(tester.getTopLeft(inAppBar(find.text('Detail'))).dx, NavigationToolbar.kMiddleSpacing);

        // Without a column the app bar keeps its default.
        await preview(tester);
        expectAppBarControls(tester);
        expect(detailAppBar().centerTitle, isNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('keeps back and actions in the app bar without a vertical bar region', (tester) async {
      // Inner landscape before a region arrives, and an iPhone 17.
      for (final (size, safeArea, edge) in [
        (const Size(951, 669), const EdgeInsets.only(right: 84, bottom: 34), HorizontalEdge.right),
        (const Size(402, 874), const EdgeInsets.only(top: 62, bottom: 34), null),
      ]) {
        await preview(tester, size: size, safeArea: safeArea, edge: edge);
        await tapVisible(tester, openDetail);
        expectAppBarControls(tester);
        await tester.tap(inAppBar(find.byTooltip('Share')));
        await tester.pumpAndSettle();
        expect(textOf(tester, lastAction), 'Share from the app bar');
        await tester.tap(inAppBar(find.widgetWithIcon(IconButton, Icons.star_outline_rounded)));
        await tester.pumpAndSettle();
        expect(
          tester.widget<IconButton>(inAppBar(find.widgetWithIcon(IconButton, Icons.star_rounded))).isSelected,
          isTrue,
        );
        await tester.tap(inAppBar(find.byType(BackButton)));
        await tester.pumpAndSettle();
        expect(find.text('Detail'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps its state while the region comes and goes', (tester) async {
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('detail-scroll')),
        matching: find.byType(Scrollable),
      );
      await preview(tester, verticalBar: innerLandscapeBar);
      await tapVisible(tester, openDetail);
      final add = find.byKey(const ValueKey('detail-add-tap'));
      await tapVisible(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(textOf(tester, detailTaps), '2 taps');
      final scrollState = tester.state(scroll);

      await preview(tester);
      expectAppBarControls(tester);
      expect(textOf(tester, detailTaps), '2 taps');
      expect(tester.state(scroll), same(scrollState));

      await preview(tester, verticalBar: innerLandscapeBar);
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(879, 124, 927, 172));
      expect(textOf(tester, detailTaps), '2 taps');
      expect(tester.state(scroll), same(scrollState));
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the right Split View window column and keeps the left window app bar', (tester) async {
      await preview(tester, size: splitView, verticalBar: rightWindowBar);
      await tapVisible(tester, openDetail);
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(397, 124, 445, 172));
      expect(tester.getRect(find.byTooltip('Share')), const Rect.fromLTRB(397, 184, 445, 232));
      expect(inAppBar(find.byType(IconButton)), findsNothing);

      // The left window has no side inset, so cells would cover the page.
      await preview(
        tester,
        size: splitView,
        safeArea: const EdgeInsets.only(bottom: 34),
        edge: HorizontalEdge.left,
        verticalBar: leftWindowBar,
      );
      expectAppBarControls(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('puts the app bar row with back in the inner portrait band', (tester) async {
      const size = Size(669, 951);
      await preview(
        tester,
        size: size,
        safeArea: const EdgeInsets.only(top: 82, bottom: 34),
        edge: null,
        topBar: _innerPortraitBand,
      );
      await tapVisible(tester, openDetail);
      // The pane is the whole window, so the row fills the band.
      expect(tester.getRect(inAppBar(find.byType(NavigationToolbar))), const Rect.fromLTRB(16, 24, 525, 72));
      expectAppBarControls(tester);
      expect(tester.getRect(inAppBar(find.byType(BackButton))), const Rect.fromLTRB(20, 24, 68, 72));
      expect(tester.takeException(), isNull);
    });

    testWidgets('more actions fill the column: back, seven actions, and the overflow cell', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      await tapVisible(tester, openDetail);
      await tapVisible(tester, moreActions);
      const shown = [...innerLandscapeActions, 'Copy link', 'Bookmark', 'Download', 'Print'];
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(879, 124, 927, 172));
      for (final (index, label) in shown.indexed) {
        expect(tester.getRect(find.byTooltip(label)), Rect.fromLTWH(879, 184 + 52.0 * index, 48, 48), reason: label);
      }
      expect(tester.getRect(find.byTooltip('Show menu')), const Rect.fromLTRB(879, 548, 927, 596));
      for (final label in ['Edit', 'Archive', 'Report']) {
        expect(find.byTooltip(label), findsNothing, reason: label);
      }
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(textOf(tester, lastAction), 'Archive from x 879–927, y 548–596 via the overflow menu');

      // Without the region, the app bar keeps the first three and a menu for the rest.
      await preview(tester);
      expectAppBarControls(tester);
      await tester.tap(inAppBar(find.byTooltip('More actions')));
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(textOf(tester, lastAction), 'Report from the app bar');
      expect(tester.takeException(), isNull);
    });

    testWidgets('metrics show the top bar top that comes with the vertical bar region', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      expect(find.text('Right edge · x 879–927, y 124–635 · top bar top 24'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('tab screen', () {
    // The destination boxes of a RailPlacement.systemRailWidth rail.
    const innerLandscapeDestinations = {
      'Layout': Rect.fromLTRB(855, 455, 951, 515),
      'State': Rect.fromLTRB(855, 515, 951, 575),
      'About': Rect.fromLTRB(855, 575, 951, 635),
    };
    const iPad = Size(1376, 1032);
    const iPadSafeArea = EdgeInsets.only(top: 32, bottom: 25);
    const iPadDestinations = {
      'Layout': Rect.fromLTRB(0, 433.5, 80, 493.5),
      'State': Rect.fromLTRB(0, 493.5, 80, 553.5),
      'About': Rect.fromLTRB(0, 553.5, 80, 613.5),
    };
    // The outer landscape display with the column on the left, where the status bar is hidden.
    const outerLandscape = Size(678, 466);
    const outerLandscapeLeftBar = VerticalBarRegion(
      rect: Rect.fromLTRB(24, 82, 72, 432),
      edge: HorizontalEdge.left,
      viewSize: outerLandscape,
      topBarTop: _topBarTop,
    );
    const actions = ['Reset counter', 'About the kit'];
    // Above the rail's floor, 184 - 12 = 172 on every inner landscape tab: the first cell, then 52 apart.
    const firstCell = Rect.fromLTRB(879, 124, 927, 172);
    const secondCell = Rect.fromLTRB(879, 176, 927, 224);
    final showMenuButton = find.byTooltip('Show menu');
    Finder inAppBar(Finder finder) => find.descendant(of: find.byType(AppBar), matching: finder);
    Finder inMenu(String label) => find.descendant(of: find.byType(PopupMenuItem<int>), matching: find.text(label));

    Rect destination(WidgetTester tester, String label) => tester.getRect(
      find
          .ancestor(
            of: find.descendant(of: find.byType(NavigationRail), matching: find.text(label)),
            matching: find.byWidgetPredicate((widget) => widget is InkResponse),
          )
          .first,
    );

    int selectedTab(WidgetTester tester) => tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;

    /// Both actions are in the content app bar, and only there.
    void expectAppBarActions(WidgetTester tester) {
      for (final label in actions) {
        expect(inAppBar(find.byTooltip(label)), findsOneWidget, reason: label);
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
      expect(showMenuButton, findsNothing);
    }

    /// The column holds both actions, in its first two cells, and the app bar none.
    void expectColumnActions(WidgetTester tester, {double dx = 0}) {
      expect(tester.getRect(find.byTooltip('Reset counter')), firstCell.translate(dx, 0));
      expect(tester.getRect(find.byTooltip('About the kit')), secondCell.translate(dx, 0));
      expect(inAppBar(find.byType(IconButton)), findsNothing);
      expect(showMenuButton, findsNothing);
    }

    /// Opens the State lab and sets the number of rail tabs.
    Future<void> showRailTabs(WidgetTester tester, int count) async {
      if (selectedTab(tester) != 1) {
        await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('State')));
        await tester.pumpAndSettle();
      }
      final segment = find.descendant(of: find.byKey(const ValueKey('rail-tabs')), matching: find.text('$count'));
      await tester.ensureVisible(segment);
      await tester.pumpAndSettle();
      await tester.tap(segment);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(NavigationRail), matching: find.byWidgetPredicate((w) => w is InkResponse)),
        findsNWidgets(count),
      );
    }

    testWidgets('draws its actions in the inner landscape column above the rail', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      expectColumnActions(tester);
      // The rail stays where it was without the shell.
      for (final MapEntry(key: label, value: rect) in innerLandscapeDestinations.entries) {
        expect(destination(tester, label), rect, reason: label);
      }

      await tester.tap(fab);
      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.text('2 taps'), findsOneWidget);
      await tester.tap(find.byTooltip('Reset counter'));
      await tester.pumpAndSettle();
      expect(find.text('0 taps'), findsOneWidget);
      await tester.tap(find.byTooltip('About the kit'));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      expect(find.text('Let the system lead.'), findsOneWidget);
      expectColumnActions(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keeps the tab title at the leading edge on iOS while the column holds the actions',
      (tester) async {
        AppBar tabAppBar() => tester.widget<AppBar>(find.byType(AppBar));

        // An iOS AppBar centres a title with fewer than two actions; UIKit leaves it at the leading edge.
        await preview(tester, verticalBar: innerLandscapeBar);
        expectColumnActions(tester);
        expect(tabAppBar().centerTitle, isFalse);
        expect(tester.getTopLeft(inAppBar(find.text('Overview'))).dx, NavigationToolbar.kMiddleSpacing);

        // Without a column the app bar keeps its default.
        await preview(tester);
        expectAppBarActions(tester);
        expect(tabAppBar().centerTitle, isNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('keeps the rail and the app bar actions on iPad', (tester) async {
      await preview(tester, size: iPad, safeArea: iPadSafeArea, edge: null);
      for (final MapEntry(key: label, value: rect) in iPadDestinations.entries) {
        expect(destination(tester, label), rect, reason: label);
      }
      expectAppBarActions(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the right Split View window column and keeps the app bar where the column is not used', (
      tester,
    ) async {
      await preview(tester, size: splitView, verticalBar: rightWindowBar);
      expectColumnActions(tester, dx: 397 - 879);

      // The left window has no side inset.
      await preview(
        tester,
        size: splitView,
        safeArea: const EdgeInsets.only(bottom: 34),
        edge: HorizontalEdge.left,
        verticalBar: leftWindowBar,
      );
      expectAppBarActions(tester);

      // The outer landscape display hides the status bar.
      await preview(
        tester,
        size: outerLandscape,
        safeArea: const EdgeInsets.only(left: 84, bottom: 21),
        edge: HorizontalEdge.left,
        statusBarHidden: true,
        verticalBar: outerLandscapeLeftBar,
      );
      expectAppBarActions(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gets its cells back when the detail page pops', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      final openDetail = find.byKey(const ValueKey('open-detail'));
      await tester.ensureVisible(openDetail);
      await tester.pumpAndSettle();
      await tester.tap(openDetail);
      await tester.pumpAndSettle();
      // The detail page, a root push, keeps UIKit's column. The tab route is offstage below it, so its
      // cells cannot be found here whether the shell keeps them or not.
      expect(tester.getRect(find.byTooltip('Back')), const Rect.fromLTRB(879, 124, 927, 172));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
      expectColumnActions(tester);
      // The cells are usable again, not only drawn.
      await tester.tap(find.byTooltip('About the kit'));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits the actions above a rail with more tabs', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      // Six tabs still leave room for both actions; only seven overflow, as in UIKit.
      for (final (count, expected) in [(5, 3), (6, 2), (3, 6)]) {
        await showRailTabs(tester, count);
        final top = destination(tester, 'Layout').top;
        // The cells end 12 above the rail's items, and never below the floor at 184.
        expect(VerticalBarColumn.capacity(math.max(top, 184) - 12 - 124), expected, reason: '$count tabs');
        expectColumnActions(tester);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps a rail that does not fit below the floor under the overflow cell', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar, textScale: 2);
      await showRailTabs(tester, 7);
      // The rail does not fit below the floor, so it scrolls from the padding railPaddingOf gives: the floor at
      // 184, 12 below the overflow cell, plus the rail's own 8. The plain safe area would start it at 152 + 8.
      expect(destination(tester, 'Layout').top, 192);
      expect(tester.getRect(showMenuButton), firstCell);
      for (final label in actions) {
        expect(find.byTooltip(label), findsNothing, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('moves both actions to the overflow menu beside seven tabs', (tester) async {
      await preview(tester, verticalBar: innerLandscapeBar);
      await showRailTabs(tester, 7);
      final top = destination(tester, 'Layout').top;
      // Below 236 only one cell fits above the rail.
      expect(top, lessThan(236));
      expect(VerticalBarColumn.capacity(math.max(top, 184) - 12 - 124), 1);
      expect(tester.getRect(showMenuButton), firstCell);
      for (final label in actions) {
        expect(find.byTooltip(label), findsNothing, reason: label);
      }

      // The added tabs are placeholders.
      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Tab 7')));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 1);

      await tester.tap(showMenuButton);
      await tester.pumpAndSettle();
      for (final label in actions) {
        expect(inMenu(label), findsOneWidget, reason: label);
      }
      await tester.tap(inMenu('About the kit'));
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      expect(find.text('Let the system lead.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
