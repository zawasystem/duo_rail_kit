import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometry measured with a real Scaffold before package extraction.
/// Keep these expectations independent of the implementation's calculations.

const Key _fabKey = ValueKey('fab');

/// A real Scaffold FAB; null [location] uses Material's default endFloat.
Widget _scaffold(
  FloatingActionButtonLocation? location, {
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  bool small = false,
  TextDirection textDirection = TextDirection.ltr,
  double stackedBelow = 0,
}) => MaterialApp(
  home: Directionality(
    textDirection: textDirection,
    // Simulate a panel below the Scaffold.
    child: Padding(
      padding: EdgeInsets.only(bottom: stackedBelow),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding, viewPadding: viewPadding, viewInsets: viewInsets),
          child: Scaffold(
            body: const SizedBox.expand(),
            floatingActionButton: small
                ? const FloatingActionButton.small(key: _fabKey, onPressed: null, child: Icon(Icons.add))
                : const FloatingActionButton(key: _fabKey, onPressed: null, child: Icon(Icons.add)),
            floatingActionButtonLocation: location,
          ),
        ),
      ),
    ),
  ),
);

/// Reads the FAB location/enabled state and counts rebuilds.
class _Reader extends StatelessWidget {
  const _Reader();

  static int builds = 0;
  static FloatingActionButtonLocation? location;
  static bool? enabled;

  @override
  Widget build(BuildContext context) {
    builds++;
    location = RailSideFab.locationOf(context);
    enabled = RailSideFab.enabledOf(context);
    return const SizedBox();
  }
}

void main() {
  test('bottom margin is 24 and toString returns the class name', () {
    expect(RailSideFabLocation.bottomMargin, 24);
    expect(const RailSideFabLocation().toString(), 'RailSideFabLocation');
  });

  group('RailSideFabLocation: geometry inside a real Scaffold', () {
    // Label -> (Scaffold rect, default FAB rect, custom FAB rect).
    final cases = <String, (Widget Function(FloatingActionButtonLocation?), Rect, Rect)>{
      'no bottom inset': (_scaffold, const Rect.fromLTRB(728, 528, 784, 584), const Rect.fromLTRB(728, 520, 784, 576)),
      // Default: 16 above inset 34. Custom: 24 above the bottom, overlapping the inset by 10.
      'bottom inset 34': (
        (l) => _scaffold(
          l,
          padding: const EdgeInsets.only(bottom: 34),
          viewPadding: const EdgeInsets.only(bottom: 34),
        ),
        const Rect.fromLTRB(728, 494, 784, 550),
        const Rect.fromLTRB(728, 520, 784, 576),
      ),
      'bottom inset 34 and right column 84: horizontal margin remains 16': (
        (l) => _scaffold(
          l,
          padding: const EdgeInsets.only(right: 84, bottom: 34),
          viewPadding: const EdgeInsets.only(right: 84, bottom: 34),
        ),
        const Rect.fromLTRB(644, 494, 700, 550),
        const Rect.fromLTRB(644, 520, 700, 576),
      ),
      'keyboard height 300: content ends at the keyboard top': (
        (l) => _scaffold(
          l,
          viewPadding: const EdgeInsets.only(bottom: 34),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
        const Rect.fromLTRB(728, 228, 784, 284),
        const Rect.fromLTRB(728, 220, 784, 276),
      ),
      'panel height 64 below the Scaffold: content ends at the panel top': (
        (l) => _scaffold(
          l,
          padding: const EdgeInsets.only(bottom: 34),
          viewPadding: const EdgeInsets.only(bottom: 34),
          stackedBelow: 64,
        ),
        const Rect.fromLTRB(728, 430, 784, 486),
        const Rect.fromLTRB(728, 456, 784, 512),
      ),
      'small FAB': (
        (l) => _scaffold(
          l,
          padding: const EdgeInsets.only(bottom: 34),
          viewPadding: const EdgeInsets.only(bottom: 34),
          small: true,
        ),
        const Rect.fromLTRB(736, 502, 784, 550),
        const Rect.fromLTRB(736, 528, 784, 576),
      ),
      'RTL with left column 84: matches default left placement': (
        (l) => _scaffold(
          l,
          padding: const EdgeInsets.only(left: 84, bottom: 34),
          viewPadding: const EdgeInsets.only(left: 84, bottom: 34),
          textDirection: TextDirection.rtl,
        ),
        const Rect.fromLTRB(100, 494, 156, 550),
        const Rect.fromLTRB(100, 520, 156, 576),
      ),
    };

    for (final MapEntry(key: name, value: (build, endFloat, railSide)) in cases.entries) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(build(null));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(_fabKey)),
          endFloat,
          reason: 'default endFloat geometry provides the baseline',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(build(const RailSideFabLocation()));
        await tester.pumpAndSettle();
        final fab = tester.getRect(find.byKey(_fabKey));
        expect(fab, railSide);
        expect(fab.left, endFloat.left, reason: 'horizontal placement matches default endFloat');
      });
    }
  });

  group('locationOf / enabledOf', () {
    setUp(() {
      _Reader.builds = 0;
      _Reader.location = null;
      _Reader.enabled = null;
    });

    testWidgets('without a RailSideFab ancestor: null location and false enabled', (tester) async {
      await tester.pumpWidget(const _Reader());
      expect(_Reader.location, isNull);
      expect(_Reader.enabled, isFalse);
    });

    testWidgets('disabled: null location and false enabled', (tester) async {
      await tester.pumpWidget(const RailSideFab(enabled: false, child: _Reader()));
      expect(_Reader.location, isNull);
      expect(_Reader.enabled, isFalse);
    });

    testWidgets('enabled: constant RailSideFabLocation instance and true enabled', (tester) async {
      await tester.pumpWidget(const RailSideFab(enabled: true, child: _Reader()));
      expect(_Reader.location, same(const RailSideFabLocation()));
      expect(_Reader.enabled, isTrue);
    });
  });

  group('updateShouldNotify', () {
    test('returns true only when enabled changes', () {
      const on = RailSideFab(enabled: true, child: SizedBox());
      const off = RailSideFab(enabled: false, child: SizedBox());
      expect(on.updateShouldNotify(on), isFalse);
      expect(on.updateShouldNotify(off), isTrue);
      expect(off.updateShouldNotify(on), isTrue);
      expect(off.updateShouldNotify(off), isFalse);
    });

    testWidgets('dependents rebuild only when enabled changes', (tester) async {
      var enabled = false;
      late StateSetter setOuter;
      _Reader.builds = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return RailSideFab(enabled: enabled, child: const _Reader());
          },
        ),
      );
      expect(_Reader.builds, 1);

      // (Next value, resulting build count, resulting location).
      for (final (next, builds, location) in <(bool, int, FloatingActionButtonLocation?)>[
        (false, 1, null),
        (true, 2, const RailSideFabLocation()),
        (true, 2, const RailSideFabLocation()),
        (false, 3, null),
        (false, 3, null),
      ]) {
        setOuter(() => enabled = next);
        await tester.pump();
        expect(_Reader.builds, builds, reason: 'enabled → $next');
        expect(_Reader.location, location == null ? isNull : same(location), reason: 'enabled → $next');
      }
    });
  });

  // Scaffold compares locations by identity; a stable constant avoids a shrink/reappear transition.
  testWidgets('rebuilds preserve FAB placement; new location instances trigger a transition', (tester) async {
    Widget tree(FloatingActionButtonLocation? Function(BuildContext) location, int n) => MaterialApp(
      home: RailSideFab(
        enabled: true,
        child: Builder(
          builder: (context) => Scaffold(
            body: Text('$n'),
            floatingActionButton: const FloatingActionButton(key: _fabKey, onPressed: null, child: Icon(Icons.add)),
            floatingActionButtonLocation: location(context),
          ),
        ),
      ),
    );

    await tester.pumpWidget(tree(RailSideFab.locationOf, 0));
    await tester.pumpAndSettle();
    const settled = Rect.fromLTRB(728, 520, 784, 576);
    expect(tester.getRect(find.byKey(_fabKey)), settled);

    await tester.pumpWidget(tree(RailSideFab.locationOf, 1));
    expect(tester.hasRunningAnimations, isFalse, reason: 'locationOf returns the same instance on every read');
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getRect(find.byKey(_fabKey)), settled);

    // Control: a new instance with identical geometry still has a different identity.
    // ignore: prefer_const_constructors
    await tester.pumpWidget(tree((_) => RailSideFabLocation(), 2));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.getRect(find.byKey(_fabKey)),
      isNot(settled),
      reason: 'FAB is partway through its shrink and reappear transition',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_fabKey)), settled);
  });
}
