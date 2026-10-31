import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Displays inherited edge state and counts State recreation.
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  static int created = 0;

  /// Counts inherited notifications; a parent rebuild alone reuses the const probe.
  static int builds = 0;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    return Text(
      '${VerticalBarEdge.of(context)} hidden=${VerticalBarEdge.statusBarHiddenOf(context)}',
      textDirection: TextDirection.ltr,
    );
  }
}

const HorizontalEdge _right = HorizontalEdge.right;
const HorizontalEdge _left = HorizontalEdge.left;

/// Checks [edge] without asserting status-bar visibility.
Finder _shows(HorizontalEdge? edge) => find.textContaining(RegExp('^${RegExp.escape('$edge')} hidden='));

/// Checks both [edge] and [hidden].
Finder _showsHidden(HorizontalEdge? edge, {required bool hidden}) => find.text('$edge hidden=$hidden');

/// Returns [answer] from the mocked native query and counts requests.
List<Object?> _answerGetEdge(WidgetTester tester, Object? Function() answer) {
  final calls = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, (call) async {
    calls.add(call.method);
    return answer();
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, null));
  return calls;
}

/// Delivers a simulated native edgeChanged event.
Future<void> _pushFromNative(WidgetTester tester, Object? value) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    VerticalBarEdge.channel.name,
    VerticalBarEdge.channel.codec.encodeMethodCall(MethodCall('edgeChanged', value)),
    (_) {},
  );
  await tester.pump();
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const VerticalBarEdge(child: _Probe()));
  await tester.pump();
}

/// Applies lifecycle [states] sequentially, matching OS event ordering.
Future<void> _moveLifecycle(WidgetTester tester, List<AppLifecycleState> states) async {
  states.forEach(tester.binding.handleAppLifecycleStateChanged);
  await tester.pump();
}

void main() {
  setUp(() {
    _ProbeState.created = 0;
    _ProbeState.builds = 0;
  });

  test('uses the shared channel name matching DuoRailKitPlugin', () {
    expect(VerticalBarEdge.channel.name, 'com.zawasystem.fleet/vertical_bar_edge');
  });

  group('VerticalBarEdge.parseStatusBarHidden', () {
    test('parses true and false', () {
      expect(VerticalBarEdge.parseStatusBarHidden({'edge': 'left', 'statusBarHidden': true}), isTrue);
      expect(VerticalBarEdge.parseStatusBarHidden({'edge': 'right', 'statusBarHidden': false}), isFalse);
    });

    test('missing, non-boolean, or malformed visibility defaults to false', () {
      expect(VerticalBarEdge.parseStatusBarHidden({'edge': 'right'}), isFalse);
      expect(VerticalBarEdge.parseStatusBarHidden({'edge': 'right', 'statusBarHidden': 'yes'}), isFalse);
      expect(VerticalBarEdge.parseStatusBarHidden({'edge': 'right', 'statusBarHidden': 1}), isFalse);
      expect(VerticalBarEdge.parseStatusBarHidden('right'), isFalse);
      expect(VerticalBarEdge.parseStatusBarHidden(null), isFalse);
    });
  });

  group('VerticalBarEdge.parse', () {
    test('parses native left and right edges independently of other fields', () {
      expect(VerticalBarEdge.parse({'edge': 'right'}), _right);
      expect(VerticalBarEdge.parse({'edge': 'left', 'sequence': 4}), _left);
    });

    test('none, unknown, and malformed edges resolve to null', () {
      expect(VerticalBarEdge.parse({'edge': 'none'}), isNull);
      expect(VerticalBarEdge.parse({'edge': 'top'}), isNull);
      expect(VerticalBarEdge.parse('right'), isNull, reason: 'legacy string-only payload');
      expect(VerticalBarEdge.parse(null), isNull);
    });
  });

  group('VerticalBarEdge', () {
    testWidgets('iOS: exposes the initial native query result to descendants', (tester) async {
      final calls = _answerGetEdge(tester, () => {'edge': 'right'});
      await _pump(tester);

      expect(calls, ['getEdge']);
      expect(_shows(_right), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: native events update the edge without recreating descendant State', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'right'});
      await _pump(tester);

      await _pushFromNative(tester, {'edge': 'left'});
      expect(_shows(_left), findsOneWidget);
      await _pushFromNative(tester, {'edge': 'none'});
      expect(_shows(null), findsOneWidget);
      expect(_ProbeState.created, 1, reason: 'value changes preserve the widget tree structure');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: queries on size or safe-area changes, not keyboard-only viewInsets', (tester) async {
      Object? answer = {'edge': 'right'};
      final calls = _answerGetEdge(tester, () => answer);
      tester.view
        ..physicalSize = const Size(951, 669)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester);
      expect(calls, hasLength(1));

      // Window resize, such as entering Split View.
      answer = {'edge': 'left'};
      tester.view.physicalSize = const Size(469, 669);
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(_shows(_left), findsOneWidget);

      // Switching Split View sides can change safe areas without resizing.
      answer = {'edge': 'right'};
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.padding = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      // Default viewPadding may be nonzero; count only actual changes.
      final afterPadding = calls.length;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      await tester.pumpAndSettle();
      expect(calls.length, afterPadding + 1);
      expect(_shows(_right), findsOneWidget);

      // Keyboard-only viewInsets changes do not trigger a query.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(calls.length, afterPadding + 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // Regression: an older query reply arriving after a newer trait event must not restore the old edge.
    testWidgets('iOS: newer sequence wins when an older query reply arrives late', (tester) async {
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, (call) async {
        calls++;
        if (calls == 1) {
          return {'edge': 'right', 'sequence': 1};
        }
        // Deliver event 3 (left) before completing query 2 (right).
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          VerticalBarEdge.channel.name,
          VerticalBarEdge.channel.codec.encodeMethodCall(
            const MethodCall('edgeChanged', {'edge': 'left', 'sequence': 3}),
          ),
          (_) {},
        );
        return {'edge': 'right', 'sequence': 2};
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, null));
      tester.view
        ..physicalSize = const Size(951, 669)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester);
      expect(_shows(_right), findsOneWidget);

      tester.view.physicalSize = const Size(469, 669);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(_shows(_left), findsOneWidget, reason: 'reply 2 must not overwrite the left edge from event 3');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: legacy payloads without a sequence apply in arrival order', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'right'});
      await _pump(tester);
      await _pushFromNative(tester, {'edge': 'left', 'sequence': 5});
      expect(_shows(_left), findsOneWidget);
      await _pushFromNative(tester, {'edge': 'right'});
      expect(_shows(_right), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: missing native plugin leaves a null edge for width-based fallback', (tester) async {
      // An unregistered native channel makes invokeMethod throw MissingPluginException.
      await _pump(tester);
      expect(_shows(null), findsOneWidget);

      // Retrying after a metrics change must remain safe.
      tester.view
        ..physicalSize = const Size(500, 500)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      expect(_shows(null), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: native PlatformException leaves the edge null', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        VerticalBarEdge.channel,
        (call) async => throw PlatformException(code: 'boom'),
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, null));
      await _pump(tester);
      expect(_shows(null), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: exposes status-bar visibility and defaults missing values to false', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'left', 'statusBarHidden': true});
      await _pump(tester);
      expect(_showsHidden(_left, hidden: true), findsOneWidget);

      await _pushFromNative(tester, {'edge': 'right', 'statusBarHidden': false});
      expect(_showsHidden(_right, hidden: false), findsOneWidget);
      await _pushFromNative(tester, {'edge': 'left', 'statusBarHidden': true});
      expect(_showsHidden(_left, hidden: true), findsOneWidget);
      // Missing visibility defaults to false; visibility changes apply even when the edge is unchanged.
      await _pushFromNative(tester, {'edge': 'left'});
      expect(_showsHidden(_left, hidden: false), findsOneWidget);
      expect(_ProbeState.created, 1, reason: 'value changes preserve the widget tree structure');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: stale sequences cannot overwrite status-bar visibility', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'right', 'statusBarHidden': false, 'sequence': 1});
      await _pump(tester);
      await _pushFromNative(tester, {'edge': 'left', 'statusBarHidden': true, 'sequence': 3});
      expect(_showsHidden(_left, hidden: true), findsOneWidget);
      // Discard sequence 2 when it arrives after a newer payload.
      await _pushFromNative(tester, {'edge': 'left', 'statusBarHidden': false, 'sequence': 2});
      expect(
        _showsHidden(_left, hidden: true),
        findsOneWidget,
        reason: 'stale sequence 2 must not overwrite sequence 3',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // Native visibility can change without a vertical edge. Normalize it to avoid
    // delayed, visually irrelevant rebuilds when ordinary phones rotate.
    testWidgets('iOS: visibility-only changes do not notify descendants when edge is none', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'none', 'statusBarHidden': false, 'sequence': 1});
      await _pump(tester);
      final builds = _ProbeState.builds;

      await _pushFromNative(tester, {'edge': 'none', 'statusBarHidden': true, 'sequence': 2});
      expect(_ProbeState.builds, builds, reason: 'visibility-only changes do not notify without a vertical edge');
      expect(
        _showsHidden(null, hidden: false),
        findsOneWidget,
        reason: 'visibility normalizes to false without a vertical edge',
      );
      await _pushFromNative(tester, {'edge': 'none', 'statusBarHidden': false, 'sequence': 3});
      expect(_ProbeState.builds, builds);

      // Normalized payloads still advance the sequence, so older values remain stale.
      await _pushFromNative(tester, {'edge': 'left', 'statusBarHidden': true, 'sequence': 5});
      expect(
        _showsHidden(_left, hidden: true),
        findsOneWidget,
        reason: 'visibility is exposed when a vertical edge exists',
      );
      expect(_ProbeState.builds, builds + 1);
      await _pushFromNative(tester, {'edge': 'none', 'statusBarHidden': true, 'sequence': 4});
      expect(
        _showsHidden(_left, hidden: true),
        findsOneWidget,
        reason: 'stale sequence 4 must not overwrite sequence 5',
      );
      await _pushFromNative(tester, {'edge': 'none', 'statusBarHidden': true, 'sequence': 6});
      expect(
        _showsHidden(null, hidden: false),
        findsOneWidget,
        reason: 'removing the vertical edge also clears hidden visibility',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // Native visibility is sampled, not independently observed. Refresh on resume
    // even when window size and safe areas have not changed.
    testWidgets('iOS: resuming the app queries and applies the latest native value', (tester) async {
      Object? answer = {'edge': 'right', 'statusBarHidden': false, 'sequence': 1};
      final calls = _answerGetEdge(tester, () => answer);
      await _pump(tester);
      expect(calls, hasLength(1));
      expect(_showsHidden(_right, hidden: false), findsOneWidget);

      answer = {'edge': 'right', 'statusBarHidden': true, 'sequence': 2};
      await _moveLifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]);
      expect(calls, hasLength(1), reason: 'leaving the foreground does not query native state');

      await _moveLifecycle(tester, [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]);
      expect(calls, hasLength(2), reason: 'returning to the foreground queries exactly once');
      expect(_showsHidden(_right, hidden: true), findsOneWidget);

      // Resume replies obey the same sequence-ordering rule.
      answer = {'edge': 'left', 'statusBarHidden': false, 'sequence': 2};
      await _moveLifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.resumed]);
      expect(calls, hasLength(3));
      expect(_showsHidden(_right, hidden: true), findsOneWidget, reason: 'sequence 2 has already been applied');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android: resuming the app does not query native state', (tester) async {
      final calls = _answerGetEdge(tester, () => {'edge': 'right'});
      await _pump(tester);
      await _moveLifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.resumed]);
      expect(calls, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    // Replacement initializes the new State before disposing the old one at frame end.
    testWidgets('iOS: replacing the keyed widget preserves native events for the new owner', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'right'});
      await tester.pumpWidget(const VerticalBarEdge(key: ValueKey('a'), child: _Probe()));
      await tester.pump();
      await tester.pumpWidget(const VerticalBarEdge(key: ValueKey('b'), child: _Probe()));
      await tester.pump();
      expect(_ProbeState.created, 2, reason: 'precondition: State was replaced');
      expect(_shows(_right), findsOneWidget);

      await _pushFromNative(tester, {'edge': 'left', 'sequence': 10});
      expect(_shows(_left), findsOneWidget, reason: 'disposing the old State must not remove the new owner handler');

      // Remove the handler when the final owner is disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      ByteData? reply;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        VerticalBarEdge.channel.name,
        VerticalBarEdge.channel.codec.encodeMethodCall(const MethodCall('edgeChanged', {'edge': 'right'})),
        (data) => reply = data,
      );
      expect(reply, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android: keeps a null edge without querying native state', (tester) async {
      final calls = _answerGetEdge(tester, () => {'edge': 'right'});
      await _pump(tester);

      expect(calls, isEmpty);
      expect(_shows(null), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('without a VerticalBarEdge ancestor: null edge and statusBarHidden defaults to false', (tester) async {
      await tester.pumpWidget(const _Probe());

      expect(_showsHidden(null, hidden: false), findsOneWidget);
    });

    testWidgets('disposing the widget removes its native event handler', (tester) async {
      _answerGetEdge(tester, () => {'edge': 'right'});
      await _pump(tester);

      Future<ByteData?> deliver() async {
        ByteData? reply;
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          VerticalBarEdge.channel.name,
          VerticalBarEdge.channel.codec.encodeMethodCall(const MethodCall('edgeChanged', {'edge': 'left'})),
          (data) => reply = data,
        );
        return reply;
      }

      // An installed handler returns a success envelope.
      expect(await deliver(), isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      // Without a handler, no listener responds and the reply is null.
      expect(await deliver(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  test('each test restores the defaultTargetPlatform override', () {
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
