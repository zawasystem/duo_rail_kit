import 'dart:async';

import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart'; // ignore: deprecated_member_use, unnecessary_ignore
import 'package:flutter_test/flutter_test.dart';

import 'support/actions.dart';
import 'support/duo_windows.dart';

/// Records the pushes and pops of the Navigator it observes.
class _Log extends NavigatorObserver {
  final List<String> events = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('push');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('pop');
}

/// A page with the back control and ten actions whose [kind] cell ('back' or 'overflow') hands its
/// invoke to [save], as an application control that keeps it for later would.
Widget _savingPage(String kind, void Function(VoidCallback? invoke) save) {
  Widget saving(BuildContext context, VerticalBarCell cell) {
    save(cell.invoke);
    return TextButton(onPressed: cell.invoke, child: const Text('Saved'));
  }

  return VerticalBarPage(
    actions: numberedActions(10),
    backBuilder: kind == 'back' ? saving : null,
    overflowBuilder: kind == 'overflow' ? saving : null,
    builder: (context, slots) => Scaffold(
      appBar: AppBar(title: const Text('Detail'), automaticallyImplyLeading: !slots.backInColumn),
      body: const Center(child: Text('Body')),
    ),
  );
}

/// A nested Navigator, as a tab branch holds one, whose first page is [HomePage].
Navigator _nested(GlobalKey<NavigatorState> key, _Log log) => Navigator(
  key: key,
  observers: [log],
  onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const HomePage()),
);

/// The event a saved [kind] invoke leaves in the page's Navigator when it acts.
String _acted(String kind) => kind == 'back' ? 'pop' : 'push';

/// Pushes an opaque full-screen confirmation on [navigator] and calls [then] as soon as it pops with
/// true, as an application control that asks before going back does.
Future<void> _confirmThen(NavigatorState navigator, VoidCallback then) async {
  final confirmed = await navigator.push(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ),
      ),
    ),
  );
  if (confirmed ?? false) {
    then();
  }
}

void main() {
  testWidgets('the overflow cell lists the actions in its menu; other cells list none', (tester) async {
    useWindow(tester, innerLandscape);
    final navigator = GlobalKey<NavigatorState>();
    final cells = <String, VerticalBarCell>{};
    await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: const HomePage()));
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => VerticalBarPage(
          actions: numberedActions(10),
          backBuilder: (context, cell) {
            cells['back'] = cell;
            return const SizedBox();
          },
          itemBuilder: (context, action, cell) {
            cells['action ${action.id}'] = cell;
            return null;
          },
          overflowBuilder: (context, cell) {
            cells['overflow'] = cell;
            return const SizedBox();
          },
          builder: (context, slots) => const Scaffold(body: Text('Body')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overflowed = cells['overflow']!.overflowed;
    expect(overflowed.map((action) => action.id), [7, 8, 9]);
    expect(() => overflowed.add(overflowed.first), throwsUnsupportedError);
    expect(cells.keys, containsAll(<String>['back', for (var n = 0; n < 7; n++) 'action $n']));
    for (final MapEntry(:key, :value) in cells.entries) {
      if (key != 'overflow') {
        expect(value.overflowed, isEmpty, reason: key);
      }
    }
  });

  for (final kind in ['back', 'overflow']) {
    testWidgets('a saved $kind invoke in a nested Navigator does nothing while ticking is disabled', (tester) async {
      useWindow(tester, innerLandscape);
      final inner = GlobalKey<NavigatorState>();
      final log = _Log();
      final ticking = ValueNotifier<bool>(true);
      addTearDown(ticking.dispose);
      VoidCallback? invoke;
      final home = ValueListenableBuilder<bool>(
        valueListenable: ticking,
        builder: (context, enabled, child) => TickerMode(enabled: enabled, child: child!),
        child: _nested(inner, log),
      );
      await tester.pumpWidget(duoApp(innerLandscape, home: home));
      inner.currentState!.push(MaterialPageRoute<void>(builder: (_) => _savingPage(kind, (saved) => invoke = saved)));
      await tester.pumpAndSettle();
      expect(invoke, isNotNull);
      log.events.clear();

      ticking.value = false;
      await tester.pump();
      invoke!();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(log.events, isEmpty);

      ticking.value = true;
      await tester.pump();
      invoke!();
      await tester.pumpAndSettle();
      expect(log.events, [_acted(kind)]);
    });
  }

  testWidgets('a saved back invoke in a nested Navigator does nothing while a root page covers it', (tester) async {
    useWindow(tester, innerLandscape);
    final navigator = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    final log = _Log();
    VoidCallback? invoke;
    await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: _nested(inner, log)));
    inner.currentState!.push(MaterialPageRoute<void>(builder: (_) => _savingPage('back', (saved) => invoke = saved)));
    await tester.pumpAndSettle();
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Upper'))));
    await tester.pumpAndSettle();
    log.events.clear();

    invoke!();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(log.events, isEmpty);
    expect(find.text('Upper'), findsOneWidget, reason: 'the covering root page stays');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    invoke!();
    await tester.pumpAndSettle();
    expect(log.events, ['pop']);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a saved back invoke in a nested Navigator does nothing while a root page is being pushed over it', (
    tester,
  ) async {
    useWindow(tester, innerLandscape);
    final navigator = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    final log = _Log();
    VoidCallback? invoke;
    await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: _nested(inner, log)));
    inner.currentState!.push(MaterialPageRoute<void>(builder: (_) => _savingPage('back', (saved) => invoke = saved)));
    await tester.pumpAndSettle();
    // Mid-transition: the incoming page is not opaque yet, so the page below still ticks.
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Upper'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    log.events.clear();

    invoke!();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(log.events, isEmpty);
    await tester.pumpAndSettle();
    expect(log.events, isEmpty);
    expect(find.text('Upper'), findsOneWidget, reason: 'the covering root page stays');
  });

  for (final kind in ['back', 'overflow']) {
    testWidgets('a saved $kind invoke on a root page does nothing while a root dialog covers it', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      VoidCallback? invoke;
      await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: const HomePage()));
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => _savingPage(kind, (saved) => invoke = saved)),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Dialog')),
        ),
      );
      await tester.pumpAndSettle();

      invoke!();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dialog'), findsOneWidget, reason: 'the dialog stays');
      expect(find.text('Detail'), findsOneWidget, reason: 'the page stays');
      expect(find.text('Action 9'), findsNothing, reason: 'no menu opens');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing);
      invoke!();
      await tester.pumpAndSettle();
      if (kind == 'back') {
        expect(find.text('Home'), findsOneWidget);
      } else {
        expect(find.text('Action 9'), findsOneWidget);
      }
    });
  }

  for (final kind in ['back', 'overflow']) {
    testWidgets('a saved $kind invoke in a nested Navigator does nothing while a root dialog is open', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      final log = _Log();
      VoidCallback? invoke;
      await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: _nested(inner, log)));
      inner.currentState!.push(MaterialPageRoute<void>(builder: (_) => _savingPage(kind, (saved) => invoke = saved)));
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Dialog')),
        ),
      );
      await tester.pumpAndSettle();
      log.events.clear();

      invoke!();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(log.events, isEmpty);
      expect(find.text('Dialog'), findsOneWidget, reason: 'the dialog stays');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing);
      invoke!();
      await tester.pumpAndSettle();
      expect(log.events, [_acted(kind)]);
    });
  }

  testWidgets('a saved back invoke two Navigators deep follows the routes that hold both', (tester) async {
    useWindow(tester, innerLandscape);
    final navigator = GlobalKey<NavigatorState>();
    final middle = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    final log = _Log();
    VoidCallback? invoke;
    final home = Navigator(
      key: middle,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _nested(inner, log)),
    );
    await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: home));
    inner.currentState!.push(MaterialPageRoute<void>(builder: (_) => _savingPage('back', (saved) => invoke = saved)));
    await tester.pumpAndSettle();
    log.events.clear();

    // The middle Navigator's top route covers the one that holds the inner Navigator, then the root's.
    for (final covering in [middle, navigator]) {
      unawaited(
        showDialog<void>(
          context: covering.currentContext!,
          useRootNavigator: false,
          builder: (_) => const AlertDialog(content: Text('Dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(covering), matching: find.text('Dialog')), findsOneWidget);
      invoke!();
      await tester.pumpAndSettle();
      expect(log.events, isEmpty);
      covering.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing);
    }

    invoke!();
    await tester.pumpAndSettle();
    expect(log.events, ['pop']);
  });

  // The confirmation is gone from the routes at once, but its Overlay turns the tickers below it back on
  // only in the next frame; `then` runs before that frame.
  testWidgets('a saved back invoke on a root page acts right after a full-screen confirmation pops', (tester) async {
    useWindow(tester, innerLandscape);
    final navigator = GlobalKey<NavigatorState>();
    VoidCallback? invoke;
    await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: const HomePage()));
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => _savingPage('back', (saved) => invoke = saved)),
    );
    await tester.pumpAndSettle();
    unawaited(_confirmThen(navigator.currentState!, () => invoke!()));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing, reason: 'the confirmation covers the page');

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('Detail'), findsNothing, reason: 'the saved back popped the page');
    expect(find.text('Home'), findsOneWidget);
  });

  for (final onRoot in [false, true]) {
    final where = onRoot ? 'the root' : 'its';
    testWidgets('a saved back invoke in a nested Navigator acts right after a full-screen confirmation on $where '
        'Navigator pops', (tester) async {
      useWindow(tester, innerLandscape);
      final navigator = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      final log = _Log();
      VoidCallback? invoke;
      await tester.pumpWidget(duoApp(innerLandscape, navigatorKey: navigator, home: _nested(inner, log)));
      inner.currentState!.push(MaterialPageRoute<void>(builder: (_) => _savingPage('back', (saved) => invoke = saved)));
      await tester.pumpAndSettle();
      unawaited(_confirmThen((onRoot ? navigator : inner).currentState!, () => invoke!()));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing, reason: 'the confirmation covers the page');
      log.events.clear();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(log.events, [if (!onRoot) 'pop', 'pop'], reason: 'the confirmation, then the page');
      expect(find.text('Home'), findsOneWidget);
    });
  }
}
