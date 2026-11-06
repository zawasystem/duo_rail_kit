import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/edge/bar_regions.dart' show parseTopBarRegion, parseVerticalBarRegion;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/duo_windows.dart';
import 'support/native_channel.dart';

/// `bar(onEdge: .top)` on the iPhone Duo inner portrait display. Recorded on the iOS 27.2 Simulator.
const Map<String, Object> _innerPortraitTopBar = {
  'left': 16.0,
  'top': 24.0,
  'right': 525.0,
  'bottom': 72.0,
  'safeTop': 82.0,
  'viewWidth': 669.0,
  'viewHeight': 951.0,
};

/// iPhone 17 portrait: the region starts at the 62-point safe-area top. Its x range is not
/// measured; the full width is used.
const Map<String, Object> _iPhone17TopBar = {
  'left': 0.0,
  'top': 62.0,
  'right': 402.0,
  'bottom': 106.0,
  'safeTop': 62.0,
  'viewWidth': 402.0,
  'viewHeight': 874.0,
};

/// Duo inner landscape: the region is at y 24-72 but the top inset is 0. Its x range is not
/// measured; the area left of the 84-point column is used.
const Map<String, Object> _innerLandscapeTopBar = {
  'left': 16.0,
  'top': 24.0,
  'right': 867.0,
  'bottom': 72.0,
  'safeTop': 0.0,
  'viewWidth': 951.0,
  'viewHeight': 669.0,
};

/// The `bar(onEdge: .right)` payload of [innerLandscape]'s region.
const Map<String, Object> _innerLandscapeVerticalBar = {
  'left': 879.0,
  'top': 124.0,
  'right': 927.0,
  'bottom': 635.0,
  'viewWidth': 951.0,
  'viewHeight': 669.0,
};

/// The same entry with `topBarTop`, the top of `bar(onEdge: .top)` measured at y 24 in UIKit's window.
const Map<String, Object> _innerLandscapeVerticalBarWithTop = {..._innerLandscapeVerticalBar, 'topBarTop': 24.0};

const TopBarRegion _innerPortraitRegion = TopBarRegion(
  rect: Rect.fromLTRB(16, 24, 525, 72),
  safeTop: 82,
  viewSize: Size(669, 951),
);

const VerticalBarRegion _innerLandscapeRegion = VerticalBarRegion(
  rect: Rect.fromLTRB(879, 124, 927, 635),
  edge: HorizontalEdge.right,
  viewSize: Size(951, 669),
);

const VerticalBarRegion _innerLandscapeRegionWithTop = VerticalBarRegion(
  rect: Rect.fromLTRB(879, 124, 927, 635),
  edge: HorizontalEdge.right,
  viewSize: Size(951, 669),
  topBarTop: 24,
);

Map<String, Object?> _with(Map<String, Object> entry, String field, Object? value) => {...entry, field: value};

Map<String, Object?> _without(Map<String, Object> entry, String field) => {...entry}..remove(field);

/// Depends only on the edge scope; counts notifications and State creation.
class _EdgeProbe extends StatefulWidget {
  const _EdgeProbe();

  @override
  State<_EdgeProbe> createState() => _EdgeProbeState();
}

class _EdgeProbeState extends State<_EdgeProbe> {
  static int created = 0;
  static int builds = 0;
  static HorizontalEdge? edge;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    edge = VerticalBarEdge.of(context);
    VerticalBarEdge.statusBarHiddenOf(context);
    return const SizedBox.shrink();
  }
}

/// Depends only on the region scope and the MediaQuery aspects read by `of`.
class _RegionProbe extends StatefulWidget {
  const _RegionProbe();

  @override
  State<_RegionProbe> createState() => _RegionProbeState();
}

class _RegionProbeState extends State<_RegionProbe> {
  static int created = 0;
  static int builds = 0;
  static TopBarRegion? topBar;
  static VerticalBarRegion? verticalBar;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    topBar = TopBarRegion.of(context);
    verticalBar = VerticalBarRegion.of(context);
    return const SizedBox.shrink();
  }
}

const Widget _probes = Directionality(
  textDirection: TextDirection.ltr,
  child: Column(children: [_EdgeProbe(), _RegionProbe()]),
);

Future<void> _pumpVerticalBarEdge(WidgetTester tester) async {
  await tester.pumpWidget(const VerticalBarEdge(child: _probes));
  await tester.pump();
}

/// Injects [topBar] and [verticalBar] directly, as an application test would.
Future<void> _pumpScope(
  WidgetTester tester, {
  TopBarRegion? topBar,
  VerticalBarRegion? verticalBar,
  Widget child = _probes,
}) => tester.pumpWidget(BarRegionScope(topBar: topBar, verticalBar: verticalBar, child: child));

/// Checks the production chain `VerticalBarEdgeScope > BarRegionScope`, independent of values.
void _expectScopeChain(WidgetTester tester) {
  final scope = find.byType(BarRegionScope);
  expect(scope, findsOneWidget);
  Widget? parent;
  tester.element(scope).visitAncestorElements((element) {
    parent = element.widget;
    return false;
  });
  expect(parent, isA<VerticalBarEdgeScope>());
}

void main() {
  setUp(() {
    _EdgeProbeState.created = 0;
    _EdgeProbeState.builds = 0;
    _EdgeProbeState.edge = null;
    _RegionProbeState.created = 0;
    _RegionProbeState.builds = 0;
    _RegionProbeState.topBar = null;
    _RegionProbeState.verticalBar = null;
  });

  group('parseTopBarRegion', () {
    test('accepts the measured iPhone Duo inner portrait band', () {
      final region = parseTopBarRegion({'edge': 'none', 'statusBarHidden': false, 'topBar': _innerPortraitTopBar});
      expect(region, _innerPortraitRegion);
      expect(region!.rect, const Rect.fromLTRB(16, 24, 525, 72));
      expect(region.safeTop, 82);
      expect(region.viewSize, const Size(669, 951));
    });

    test('accepts integer values from the codec', () {
      final entry = {for (final MapEntry(:key, :value) in _innerPortraitTopBar.entries) key: (value as double).toInt()};
      expect(parseTopBarRegion({'topBar': entry}), _innerPortraitRegion);
    });

    test('rejects iPhone 17, where the region starts at the safe-area top', () {
      expect(parseTopBarRegion({'topBar': _iPhone17TopBar}), isNull);
    });

    test('rejects Duo inner landscape, which has no top inset', () {
      expect(parseTopBarRegion({'topBar': _innerLandscapeTopBar}), isNull);
    });

    test('allows the bottom to end at most 0.5 below the safe-area top', () {
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'bottom', 82.0)})?.rect.bottom, 82);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'bottom', 82.5)})?.rect.bottom, 82.5);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'bottom', 82.6)}), isNull);
    });

    test('rejects a band that starts at or below the safe-area top or above the window', () {
      final atSafeTop = {..._innerPortraitTopBar, 'top': 82.0, 'bottom': 82.5};
      expect(parseTopBarRegion({'topBar': atSafeTop}), isNull);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'top', -1.0)}), isNull);
    });

    test('payloads without a valid topBar entry return null', () {
      expect(parseTopBarRegion(null), isNull);
      expect(parseTopBarRegion('topBar'), isNull);
      expect(parseTopBarRegion({'edge': 'none', 'statusBarHidden': false, 'sequence': 1}), isNull, reason: '0.1.1');
      expect(parseTopBarRegion({'topBar': null}), isNull);
      expect(parseTopBarRegion({'topBar': 'band'}), isNull);
      expect(parseTopBarRegion({'topBar': <String, Object>{}}), isNull);
      for (final field in _innerPortraitTopBar.keys) {
        expect(parseTopBarRegion({'topBar': _without(_innerPortraitTopBar, field)}), isNull, reason: 'no $field');
        expect(
          parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, field, '1')}),
          isNull,
          reason: 'string $field',
        );
        expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, field, double.nan)}), isNull, reason: field);
        expect(
          parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, field, double.infinity)}),
          isNull,
          reason: field,
        );
      }
    });

    test('rejects empty rectangles and rectangles outside the view', () {
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'right', 16.0)}), isNull);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'right', 10.0)}), isNull);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'bottom', 24.0)}), isNull);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'left', -1.0)}), isNull);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'right', 669.6)}), isNull);
      expect(parseTopBarRegion({'topBar': _with(_innerPortraitTopBar, 'viewWidth', 0.0)}), isNull);
    });
  });

  group('parseVerticalBarRegion', () {
    test('accepts the measured inner landscape right column with its edge', () {
      final payload = {'edge': 'right', 'verticalBar': _innerLandscapeVerticalBar};
      expect(parseVerticalBarRegion(payload, HorizontalEdge.right), _innerLandscapeRegion);
    });

    test('requires a vertical edge', () {
      expect(parseVerticalBarRegion({'verticalBar': _innerLandscapeVerticalBar}, null), isNull);
    });

    test('payloads without a valid verticalBar entry return null', () {
      const edge = HorizontalEdge.right;
      expect(parseVerticalBarRegion(null, edge), isNull);
      expect(parseVerticalBarRegion({'edge': 'right', 'statusBarHidden': false, 'sequence': 1}, edge), isNull);
      expect(parseVerticalBarRegion({'verticalBar': 'column'}, edge), isNull);
      for (final field in _innerLandscapeVerticalBar.keys) {
        final missing = _without(_innerLandscapeVerticalBar, field);
        expect(parseVerticalBarRegion({'verticalBar': missing}, edge), isNull, reason: 'no $field');
        final invalid = _with(_innerLandscapeVerticalBar, field, double.nan);
        expect(parseVerticalBarRegion({'verticalBar': invalid}, edge), isNull, reason: field);
      }
    });

    test('rejects empty rectangles and rectangles outside the view', () {
      const edge = HorizontalEdge.right;
      for (final (field, value) in [('right', 879.0), ('bottom', 100.0), ('left', -1.0), ('right', 951.6)]) {
        final entry = _with(_innerLandscapeVerticalBar, field, value);
        expect(parseVerticalBarRegion({'verticalBar': entry}, edge), isNull, reason: '$field $value');
      }
    });

    test('an entry without topBarTop, as from older native code, keeps the region with a null field', () {
      final region = parseVerticalBarRegion({'verticalBar': _innerLandscapeVerticalBar}, HorizontalEdge.right);
      expect(region, _innerLandscapeRegion);
      expect(region!.topBarTop, isNull);
    });

    test('accepts the top bar row top reported with the region', () {
      final region = parseVerticalBarRegion({'verticalBar': _innerLandscapeVerticalBarWithTop}, HorizontalEdge.right);
      expect(region, _innerLandscapeRegionWithTop);
      expect(region!.topBarTop, 24);
      expect(region.rect, const Rect.fromLTRB(879, 124, 927, 635));

      final integer = _with(_innerLandscapeVerticalBar, 'topBarTop', 24);
      expect(parseVerticalBarRegion({'verticalBar': integer}, HorizontalEdge.right)?.topBarTop, 24.0);
    });

    test('accepts topBarTop from 0 up to just above the region bottom', () {
      for (final value in [0.0, 124.0, 634.5]) {
        final entry = _with(_innerLandscapeVerticalBar, 'topBarTop', value);
        expect(parseVerticalBarRegion({'verticalBar': entry}, HorizontalEdge.right)?.topBarTop, value);
      }
    });

    test('an invalid topBarTop nulls only that field and keeps the region', () {
      for (final value in <Object?>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1.0,
        -0.5,
        635.0,
        700.0,
        '24',
        true,
        null,
        <String, Object>{},
      ]) {
        final entry = _with(_innerLandscapeVerticalBar, 'topBarTop', value);
        final region = parseVerticalBarRegion({'verticalBar': entry}, HorizontalEdge.right);
        expect(region, _innerLandscapeRegion, reason: 'topBarTop $value');
        expect(region!.topBarTop, isNull, reason: 'topBarTop $value');
      }
    });

    test('an invalid region is rejected whatever its topBarTop', () {
      final entry = {..._innerLandscapeVerticalBarWithTop, 'right': 879.0};
      expect(parseVerticalBarRegion({'verticalBar': entry}, HorizontalEdge.right), isNull);
      expect(parseVerticalBarRegion({'verticalBar': _innerLandscapeVerticalBarWithTop}, null), isNull);
    });
  });

  group('TopBarRegion.paddingFor', () {
    test('a full-width header places the row in the band', () {
      expect(
        _innerPortraitRegion.paddingFor(const Rect.fromLTWH(0, 0, 669, 130)),
        const EdgeInsets.fromLTRB(16, 24, 144, 0),
      );
    });

    test('a pane beside a left rail keeps no left inset', () {
      expect(
        _innerPortraitRegion.paddingFor(const Rect.fromLTRB(84, 0, 669, 130)),
        const EdgeInsets.fromLTRB(0, 24, 144, 0),
      );
    });

    test('edges already inside the band receive zero, never a negative inset', () {
      expect(_innerPortraitRegion.paddingFor(const Rect.fromLTRB(100, 30, 400, 100)), EdgeInsets.zero);
    });
  });

  group('value equality', () {
    test('TopBarRegion compares rect, safeTop, and viewSize', () {
      const same = TopBarRegion(rect: Rect.fromLTRB(16, 24, 525, 72), safeTop: 82, viewSize: Size(669, 951));
      expect(same, _innerPortraitRegion);
      expect(same.hashCode, _innerPortraitRegion.hashCode);
      expect(
        const TopBarRegion(rect: Rect.fromLTRB(16, 24, 525, 72), safeTop: 62, viewSize: Size(669, 951)),
        isNot(_innerPortraitRegion),
      );
      expect(
        const TopBarRegion(rect: Rect.fromLTRB(16, 24, 500, 72), safeTop: 82, viewSize: Size(669, 951)),
        isNot(_innerPortraitRegion),
      );
    });

    test('VerticalBarRegion compares rect, edge, and viewSize', () {
      const same = VerticalBarRegion(
        rect: Rect.fromLTRB(879, 124, 927, 635),
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
      );
      expect(same, _innerLandscapeRegion);
      expect(same.hashCode, _innerLandscapeRegion.hashCode);
      expect(
        const VerticalBarRegion(
          rect: Rect.fromLTRB(879, 124, 927, 635),
          edge: HorizontalEdge.left,
          viewSize: Size(951, 669),
        ),
        isNot(_innerLandscapeRegion),
      );
    });

    test('VerticalBarRegion also compares topBarTop', () {
      const same = VerticalBarRegion(
        rect: Rect.fromLTRB(879, 124, 927, 635),
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
        topBarTop: 24,
      );
      expect(same, _innerLandscapeRegionWithTop);
      expect(same.hashCode, _innerLandscapeRegionWithTop.hashCode);
      expect(_innerLandscapeRegionWithTop, isNot(_innerLandscapeRegion));
      expect(_innerLandscapeRegionWithTop.hashCode, isNot(_innerLandscapeRegion.hashCode));
      const shifted = VerticalBarRegion(
        rect: Rect.fromLTRB(879, 124, 927, 635),
        edge: HorizontalEdge.right,
        viewSize: Size(951, 669),
        topBarTop: 16,
      );
      expect(shifted, isNot(_innerLandscapeRegionWithTop));
      expect(shifted.hashCode, isNot(_innerLandscapeRegionWithTop.hashCode));
    });

    test('VerticalBarRegion.toString includes topBarTop', () {
      expect(_innerLandscapeRegionWithTop.toString(), contains('topBarTop: 24.0'));
      expect(_innerLandscapeRegion.toString(), contains('topBarTop: null'));
    });
  });

  group('of', () {
    testWidgets('returns an injected band that matches the current window', (tester) async {
      useWindow(tester, innerPortrait);
      await _pumpScope(tester, topBar: _innerPortraitRegion);
      expect(_RegionProbeState.topBar, _innerPortraitRegion);
    });

    testWidgets('returns null for a stale window size, such as right after rotation', (tester) async {
      useWindow(tester, innerLandscape);
      await _pumpScope(tester, topBar: _innerPortraitRegion);
      expect(_RegionProbeState.topBar, isNull);
    });

    testWidgets('accepts size and safe-area differences up to 0.5', (tester) async {
      useWindow(tester, innerPortrait);
      const near = TopBarRegion(rect: Rect.fromLTRB(16, 24, 525, 72), safeTop: 82.5, viewSize: Size(669.5, 950.5));
      await _pumpScope(tester, topBar: near);
      expect(_RegionProbeState.topBar, near);

      const wide = TopBarRegion(rect: Rect.fromLTRB(16, 24, 525, 72), safeTop: 82, viewSize: Size(669.6, 951));
      await _pumpScope(tester, topBar: wide);
      expect(_RegionProbeState.topBar, isNull);
    });

    testWidgets('returns null for a stale safe-area top', (tester) async {
      useGeometry(tester, const Size(669, 951), const EdgeInsets.only(top: 62, bottom: 34));
      await _pumpScope(tester, topBar: _innerPortraitRegion);
      expect(_RegionProbeState.topBar, isNull);

      const shifted = TopBarRegion(rect: Rect.fromLTRB(16, 24, 525, 72), safeTop: 82.6, viewSize: Size(669, 951));
      useWindow(tester, innerPortrait);
      await _pumpScope(tester, topBar: shifted);
      expect(_RegionProbeState.topBar, isNull);
    });

    testWidgets('returns null under a subtree whose top padding was removed', (tester) async {
      useWindow(tester, innerPortrait);
      await _pumpScope(
        tester,
        topBar: _innerPortraitRegion,
        child: Builder(
          builder: (context) => MediaQuery.removePadding(context: context, removeTop: true, child: _probes),
        ),
      );
      expect(_RegionProbeState.topBar, isNull);
    });

    testWidgets('returns null without a BarRegionScope, including under a direct VerticalBarEdgeScope', (tester) async {
      useWindow(tester, innerPortrait);
      await tester.pumpWidget(const VerticalBarEdgeScope(edge: HorizontalEdge.right, child: _probes));
      expect(_RegionProbeState.topBar, isNull);
      expect(_RegionProbeState.verticalBar, isNull);
      expect(_EdgeProbeState.edge, HorizontalEdge.right);
    });

    testWidgets('keyboard-only viewInsets changes do not rebuild region dependants', (tester) async {
      useWindow(tester, innerPortrait);
      await _pumpScope(tester, topBar: _innerPortraitRegion);
      final builds = _RegionProbeState.builds;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(_RegionProbeState.builds, builds);
      expect(_RegionProbeState.topBar, _innerPortraitRegion);
    });

    testWidgets('VerticalBarRegion.of checks only the window size', (tester) async {
      useWindow(tester, innerLandscape);
      // Top spacing added by SideStatusBarInsets does not affect the vertical region.
      await _pumpScope(
        tester,
        verticalBar: _innerLandscapeRegion,
        child: const VerticalBarEdgeScope(
          edge: HorizontalEdge.right,
          child: SideStatusBarInsets(child: _probes),
        ),
      );
      expect(_RegionProbeState.verticalBar, _innerLandscapeRegion);

      useWindow(tester, innerPortrait);
      await tester.pump();
      expect(_RegionProbeState.verticalBar, isNull, reason: 'stale size after rotation');
    });
  });

  group('VerticalBarEdge regions', () {
    testWidgets('iOS: inner portrait keeps the top band without a vertical edge', (tester) async {
      useWindow(tester, innerPortrait);
      answerGetEdge(
        tester,
        () => {'edge': 'none', 'statusBarHidden': true, 'sequence': 1, 'topBar': _innerPortraitTopBar},
      );
      await _pumpVerticalBarEdge(tester);

      expect(_RegionProbeState.topBar, _innerPortraitRegion);
      expect(_RegionProbeState.verticalBar, isNull);
      expect(_EdgeProbeState.edge, isNull);
      _expectScopeChain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: inner landscape exposes the vertical region with its edge', (tester) async {
      useWindow(tester, innerLandscape);
      answerGetEdge(
        tester,
        () => {'edge': 'right', 'statusBarHidden': false, 'sequence': 1, 'verticalBar': _innerLandscapeVerticalBar},
      );
      await _pumpVerticalBarEdge(tester);

      expect(_RegionProbeState.verticalBar, _innerLandscapeRegion);
      expect(_RegionProbeState.topBar, isNull);
      expect(_EdgeProbeState.edge, HorizontalEdge.right);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: a topBarTop-only change updates region dependants, not edge dependants', (tester) async {
      useWindow(tester, innerLandscape);
      answerGetEdge(tester, () => {'edge': 'right', 'sequence': 1, 'verticalBar': _innerLandscapeVerticalBar});
      await _pumpVerticalBarEdge(tester);
      expect(_RegionProbeState.verticalBar, _innerLandscapeRegion);
      final edgeBuilds = _EdgeProbeState.builds;
      final regionBuilds = _RegionProbeState.builds;

      await pushFromNative(tester, {'edge': 'right', 'sequence': 2, 'verticalBar': _innerLandscapeVerticalBarWithTop});
      expect(_RegionProbeState.verticalBar, _innerLandscapeRegionWithTop);
      expect(_RegionProbeState.builds, regionBuilds + 1);
      expect(_EdgeProbeState.builds, edgeBuilds);

      // An identical payload with a newer sequence does not notify again.
      await pushFromNative(tester, {'edge': 'right', 'sequence': 3, 'verticalBar': _innerLandscapeVerticalBarWithTop});
      expect(_RegionProbeState.builds, regionBuilds + 1);
      expect(_RegionProbeState.created, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: a vertical region without an edge is ignored', (tester) async {
      useWindow(tester, innerLandscape);
      answerGetEdge(tester, () => {'edge': 'none', 'sequence': 1, 'verticalBar': _innerLandscapeVerticalBar});
      await _pumpVerticalBarEdge(tester);
      expect(_RegionProbeState.verticalBar, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: payloads without region keys leave both regions null', (tester) async {
      useWindow(tester, innerPortrait);
      answerGetEdge(tester, () => {'edge': 'none', 'statusBarHidden': false, 'sequence': 1});
      await _pumpVerticalBarEdge(tester);
      expect(_RegionProbeState.topBar, isNull);
      expect(_RegionProbeState.verticalBar, isNull);
      _expectScopeChain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // An older query reply arriving after a newer event must not remove the newer band.
    testWidgets('iOS: newer sequence wins when an older reply without a band arrives late', (tester) async {
      useWindow(tester, innerPortrait);
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, (call) async {
        calls++;
        if (calls == 1) {
          return {'edge': 'none', 'sequence': 1};
        }
        // Deliver event 3 (with the band) before completing query 2 (without it).
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          VerticalBarEdge.channel.name,
          VerticalBarEdge.channel.codec.encodeMethodCall(
            const MethodCall('edgeChanged', {'edge': 'none', 'sequence': 3, 'topBar': _innerPortraitTopBar}),
          ),
          (_) {},
        );
        return {'edge': 'none', 'sequence': 2};
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, null));
      await _pumpVerticalBarEdge(tester);
      expect(_RegionProbeState.topBar, isNull);

      [AppLifecycleState.inactive, AppLifecycleState.resumed].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();
      expect(calls, 2);
      expect(_RegionProbeState.topBar, _innerPortraitRegion, reason: 'reply 2 must not clear the band from event 3');

      // A stale event cannot restore an older region either.
      await pushFromNative(tester, {'edge': 'none', 'sequence': 2});
      expect(_RegionProbeState.topBar, _innerPortraitRegion);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: region-only changes do not rebuild edge-only dependants', (tester) async {
      useWindow(tester, innerPortrait);
      answerGetEdge(tester, () => {'edge': 'none', 'sequence': 1, 'topBar': _innerPortraitTopBar});
      await _pumpVerticalBarEdge(tester);
      final edgeBuilds = _EdgeProbeState.builds;
      final regionBuilds = _RegionProbeState.builds;

      // For example, the status display widens and the band shrinks.
      await pushFromNative(tester, {
        'edge': 'none',
        'sequence': 2,
        'topBar': _with(_innerPortraitTopBar, 'right', 480.0),
      });
      expect(_RegionProbeState.topBar?.rect.right, 480);
      expect(_RegionProbeState.builds, regionBuilds + 1);
      expect(_EdgeProbeState.builds, edgeBuilds, reason: 'the edge scope does not notify for regions');

      await pushFromNative(tester, {'edge': 'none', 'sequence': 3});
      expect(_RegionProbeState.topBar, isNull);
      expect(_RegionProbeState.builds, regionBuilds + 2);
      expect(_EdgeProbeState.builds, edgeBuilds);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: edge-only changes do not rebuild region-only dependants', (tester) async {
      useWindow(tester, innerPortrait);
      answerGetEdge(tester, () => {'edge': 'none', 'sequence': 1, 'topBar': _innerPortraitTopBar});
      await _pumpVerticalBarEdge(tester);
      final regionBuilds = _RegionProbeState.builds;

      await pushFromNative(tester, {'edge': 'left', 'sequence': 2, 'topBar': _innerPortraitTopBar});
      expect(_EdgeProbeState.edge, HorizontalEdge.left);
      expect(_RegionProbeState.builds, regionBuilds);
      expect(_RegionProbeState.topBar, _innerPortraitRegion);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: regions appearing and disappearing keep the widget tree shape', (tester) async {
      useWindow(tester, innerPortrait);
      answerGetEdge(tester, () => {'edge': 'none', 'sequence': 1});
      await _pumpVerticalBarEdge(tester);
      _expectScopeChain(tester);

      await pushFromNative(tester, {'edge': 'none', 'sequence': 2, 'topBar': _innerPortraitTopBar});
      expect(_RegionProbeState.topBar, _innerPortraitRegion);
      _expectScopeChain(tester);

      useWindow(tester, innerLandscape);
      await tester.pump();
      await pushFromNative(tester, {'edge': 'right', 'sequence': 10, 'verticalBar': _innerLandscapeVerticalBar});
      expect(_RegionProbeState.topBar, isNull);
      expect(_RegionProbeState.verticalBar, _innerLandscapeRegion);
      _expectScopeChain(tester);

      await pushFromNative(tester, {'edge': 'none', 'sequence': 11});
      expect(_RegionProbeState.verticalBar, isNull);
      _expectScopeChain(tester);
      expect(_EdgeProbeState.created, 1, reason: 'value changes preserve descendant State');
      expect(_RegionProbeState.created, 1, reason: 'value changes preserve descendant State');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android: never queries native state and exposes no regions', (tester) async {
      useWindow(tester, innerPortrait);
      final calls = answerGetEdge(tester, () => {'edge': 'none', 'sequence': 1, 'topBar': _innerPortraitTopBar});
      await _pumpVerticalBarEdge(tester);
      expect(calls, isEmpty);
      expect(_RegionProbeState.topBar, isNull);
      expect(_RegionProbeState.verticalBar, isNull);
      _expectScopeChain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
