import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Content probe that counts State recreation.
class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  static int created = 0;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

const Key _railKey = ValueKey('rail');
const Widget _rail = SizedBox(key: _railKey, width: 64, height: double.infinity);

Widget _row(HorizontalEdge? railEdge, {TextDirection textDirection = TextDirection.ltr}) => Directionality(
  textDirection: textDirection,
  child: RailSideRow(railEdge: railEdge, rail: _rail, content: const _Content()),
);

void main() {
  setUp(() => _ContentState.created = 0);

  // Test window: 800 x 600 logical pixels.
  const width = 800.0;

  testWidgets('left: rail starts at x=0 and content fills the remaining width', (tester) async {
    await tester.pumpWidget(_row(HorizontalEdge.left));
    expect(tester.getTopLeft(find.byKey(_railKey)).dx, 0);
    expect(tester.getSize(find.byKey(_railKey)).width, 64);
    final content = tester.getRect(find.byKey(RailSideRow.contentKey));
    expect(content.left, 64);
    expect(content.right, width);
  });

  testWidgets('right: rail ends at the right edge and content fills the remaining width', (tester) async {
    await tester.pumpWidget(_row(HorizontalEdge.right));
    expect(tester.getTopRight(find.byKey(_railKey)).dx, width);
    final content = tester.getRect(find.byKey(RailSideRow.contentKey));
    expect(content.left, 0);
    expect(content.right, width - 64);
  });

  testWidgets('null: no rail and full-width content', (tester) async {
    await tester.pumpWidget(_row(null));
    expect(find.byKey(_railKey), findsNothing);
    final content = tester.getRect(find.byKey(RailSideRow.contentKey));
    expect(content.left, 0);
    expect(content.right, width);
  });

  testWidgets('content State survives left, right, and no-rail transitions', (tester) async {
    await tester.pumpWidget(_row(HorizontalEdge.left));
    final state = tester.state(find.byType(_Content));
    expect(_ContentState.created, 1);

    for (final edge in [HorizontalEdge.right, null, HorizontalEdge.left, HorizontalEdge.right, HorizontalEdge.left]) {
      await tester.pumpWidget(_row(edge));
      expect(tester.state(find.byType(_Content)), same(state), reason: '$edge');
    }
    expect(_ContentState.created, 1);
  });

  // Rail edges are physical coordinates; native leading/trailing is already resolved.
  testWidgets('RTL preserves physical left and right edges', (tester) async {
    await tester.pumpWidget(_row(HorizontalEdge.left, textDirection: TextDirection.rtl));
    expect(tester.getTopLeft(find.byKey(_railKey)).dx, 0, reason: 'left rail stays on the physical left');
    expect(tester.getRect(find.byKey(RailSideRow.contentKey)), const Rect.fromLTRB(64, 0, width, 600));

    await tester.pumpWidget(_row(HorizontalEdge.right, textDirection: TextDirection.rtl));
    expect(tester.getTopRight(find.byKey(_railKey)).dx, width, reason: 'right rail stays on the physical right');
    expect(tester.getRect(find.byKey(RailSideRow.contentKey)), const Rect.fromLTRB(0, 0, width - 64, 600));

    // Physical row placement must preserve the content's text direction.
    expect(Directionality.of(tester.element(find.byType(_Content))), TextDirection.rtl);
  });

  testWidgets('content uses the shared key without an application-provided key', (tester) async {
    await tester.pumpWidget(_row(HorizontalEdge.left));
    expect(RailSideRow.contentKey, const ValueKey('duo-rail-kit-content'));
    expect(find.byKey(RailSideRow.contentKey), findsOneWidget);
    expect(tester.widget(find.byKey(RailSideRow.contentKey)), isA<Expanded>());
  });
}
