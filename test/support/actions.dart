import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:material_ui/material_ui.dart';

void _noop(VerticalBarInvocation invocation) {}

/// Numbered actions labelled `Action <n>` with [icon]; [onPressed] receives each action's number and
/// invocation.
List<VerticalBarAction> numberedActions(
  int count, {
  Widget icon = const Icon(Icons.circle),
  void Function(int n, VerticalBarInvocation invocation)? onPressed,
}) => [
  for (var n = 0; n < count; n++)
    VerticalBarAction(
      id: n,
      icon: icon,
      label: 'Action $n',
      onPressed: onPressed == null ? _noop : (invocation) => onPressed(n, invocation),
    ),
];

/// A first page with the text 'Home'.
class const HomePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Home')));
}

/// A custom cell control that counts its taps in its own State.
class const CounterCell({super.key}) extends StatefulWidget {
  @override
  State<CounterCell> createState() => CounterCellState();
}

class CounterCellState() extends State<CounterCell> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('counter'),
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => taps++),
    child: SizedBox.square(
      dimension: VerticalBarColumn.cellExtent,
      child: Center(child: Text('$taps')),
    ),
  );
}
