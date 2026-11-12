import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:duo_rail_kit/src/toolbar/vertical_bar_action.dart' show uniqueVerticalBarActions;
import 'package:flutter/material.dart'; // ignore: deprecated_member_use, unnecessary_ignore
import 'package:flutter_test/flutter_test.dart';

/// Returns [value] unchanged; keeps a constructor call out of constant evaluation so its asserts run.
T _runtime<T>(T value) => value;

void _noop(VerticalBarInvocation invocation) {}

void _noopItem() {}

VerticalBarAction _action(Object id, {String? label, VerticalBarActionCallback? onPressed = _noop}) =>
    VerticalBarAction(id: id, icon: const Icon(Icons.share), label: label ?? 'Action $id', onPressed: onPressed);

/// The inner landscape cell of the first action: x 879-927, y 184-232.
const Rect _cell = Rect.fromLTRB(879, 184, 927, 232);

/// A tooltip position request for a target centred in [cell] of a 951 x 669 overlay.
TooltipPositionContext _position(Rect cell, Size tooltip, {Size overlay = const Size(951, 669)}) =>
    TooltipPositionContext(
      target: cell.center,
      targetSize: cell.size,
      tooltipSize: tooltip,
      verticalOffset: 24,
      overlaySize: overlay,
    );

void main() {
  group('VerticalBarAction', () {
    test('is enabled with onPressed and disabled without it', () {
      expect(_action('a').enabled, isTrue);
      expect(_action('a', onPressed: null).enabled, isFalse);
    });

    test('with menu items is enabled when at least one item is enabled', () {
      const enabled = VerticalBarMenuItem(label: 'Delete', onSelected: _noopItem);
      const disabled = VerticalBarMenuItem(label: 'Archive', onSelected: _noopItem, enabled: false);
      const some = VerticalBarAction(
        id: 'more',
        icon: Icon(Icons.more_vert),
        label: 'More',
        menuItems: [disabled, enabled],
      );
      const none = VerticalBarAction(
        id: 'more',
        icon: Icon(Icons.more_vert),
        label: 'More',
        menuItems: [disabled, disabled],
      );
      const empty = VerticalBarAction(
        id: 'more',
        icon: Icon(Icons.more_vert),
        label: 'More',
        menuItems: <VerticalBarMenuItem>[],
      );
      expect(some.enabled, isTrue);
      expect(none.enabled, isFalse, reason: 'all items are disabled');
      expect(empty.enabled, isFalse, reason: 'release builds draw an empty menu as disabled');
    });

    test('custom actions are enabled with onPressed and keep their builder', () {
      Widget builder(BuildContext context, VerticalBarCell cell) => const SizedBox();
      const custom = VerticalBarAction.custom(id: 'c', label: 'Custom', cellBuilder: _customCell);
      expect(custom.enabled, isFalse);
      expect(custom.icon, isNull);
      expect(custom.selected, isNull);
      expect(custom.menuItems, isNull);
      expect(custom.cellBuilder, _customCell);
      final pressable = VerticalBarAction.custom(id: 'c', label: 'Custom', cellBuilder: builder, onPressed: _noop);
      expect(pressable.enabled, isTrue);
      expect(pressable.pinned, isFalse);
    });

    test('standard actions have no cell builder', () {
      expect(_action('a').cellBuilder, isNull);
      expect(_action('a').pinned, isFalse);
      expect(_action('a').selected, isNull);
    });

    test('asserts a non-empty label', () {
      expect(() => _action('a', label: _runtime('')), throwsAssertionError);
      expect(
        () => VerticalBarAction.custom(id: 'c', label: _runtime(''), cellBuilder: _customCell),
        throwsAssertionError,
      );
    });

    test('asserts that menu items and onPressed are not both set', () {
      expect(
        () => VerticalBarAction(
          id: 'more',
          icon: const Icon(Icons.more_vert),
          label: 'More',
          onPressed: _runtime(_noop),
          menuItems: const [VerticalBarMenuItem(label: 'Delete', onSelected: _noopItem)],
        ),
        throwsAssertionError,
      );
    });
  });

  group('VerticalBarMenuItem', () {
    test('defaults to enabled and not destructive', () {
      const item = VerticalBarMenuItem(label: 'Delete', onSelected: _noopItem);
      expect(item.enabled, isTrue);
      expect(item.destructive, isFalse);
      expect(item.icon, isNull);
    });
  });

  group('uniqueVerticalBarActions', () {
    test('drops later actions with an id already used, keeping the order', () {
      final first = _action('share', label: 'Share');
      final second = _action('favorite', label: 'Favorite');
      final duplicate = _action('share', label: 'Share again');
      final third = _action(3, label: 'Third');
      expect(uniqueVerticalBarActions([first, second, duplicate, third]), [first, second, third]);
    });

    test('returns the same list when every id is unique', () {
      final actions = [_action('a'), _action('b')];
      expect(uniqueVerticalBarActions(actions), same(actions));
      expect(uniqueVerticalBarActions(const []), isEmpty);
    });
  });

  group('VerticalBarInvocation', () {
    test('has value equality and a readable toString', () {
      const a = VerticalBarInvocation(anchor: _cell, fromOverflowMenu: true);
      const b = VerticalBarInvocation(anchor: _cell, fromOverflowMenu: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const VerticalBarInvocation(anchor: _cell, fromOverflowMenu: false)));
      expect(a, isNot(VerticalBarInvocation(anchor: _cell.shift(const Offset(0, 52)), fromOverflowMenu: true)));
      expect(a.toString(), contains('fromOverflowMenu: true'));
    });
  });

  group('VerticalBarCell.tooltipPosition', () {
    const tooltip = Size(60, 32);

    test('places the tooltip 8 points left of a right column cell, vertically centred', () {
      const cell = VerticalBarCell(edge: HorizontalEdge.right, rect: _cell);
      // Inner edge 879 - 8 - 60 = 811; centre y 208 - 16 = 192.
      expect(cell.tooltipPosition(_position(_cell, tooltip)), const Offset(811, 192));
    });

    test('places the tooltip 8 points right of a left column cell, vertically centred', () {
      const rect = Rect.fromLTRB(24, 84, 72, 132);
      const cell = VerticalBarCell(edge: HorizontalEdge.left, rect: rect);
      expect(cell.tooltipPosition(_position(rect, tooltip)), const Offset(80, 92));
    });

    test('uses the target centre, so it follows the cell in any overlay', () {
      const cell = VerticalBarCell(edge: HorizontalEdge.right, rect: _cell);
      // The same cell while its page has slid 100 points left.
      final moved = _cell.shift(const Offset(-100, 0));
      expect(cell.tooltipPosition(_position(moved, tooltip)), const Offset(711, 192));
    });

    test('keeps the tooltip inside the overlay', () {
      const top = Rect.fromLTRB(879, 0, 927, 48);
      const cell = VerticalBarCell(edge: HorizontalEdge.right, rect: top);
      expect(
        cell.tooltipPosition(_position(top, const Size(60, 80))),
        const Offset(811, 0),
        reason: 'clamped at the top',
      );
      expect(
        cell.tooltipPosition(_position(top, const Size(900, 32))),
        const Offset(0, 8),
        reason: 'wider than the space beside the cell',
      );

      const left = Rect.fromLTRB(24, 620, 72, 668);
      const leftCell = VerticalBarCell(edge: HorizontalEdge.left, rect: left);
      expect(
        leftCell.tooltipPosition(_position(left, const Size(450, 80), overlay: const Size(469, 669))),
        const Offset(19, 589),
        reason: 'clamped at the right and bottom edges',
      );
    });

    test('cells default to no invoke callback', () {
      const cell = VerticalBarCell(edge: HorizontalEdge.right, rect: _cell);
      expect(cell.invoke, isNull);
    });
  });

  group('VerticalBarCell.tooltipMaxWidth', () {
    test('is the room on the inner side, less the gap', () {
      const right = VerticalBarCell(edge: HorizontalEdge.right, rect: _cell);
      // 879 - 8.
      expect(right.tooltipMaxWidth(951), 871);
      const left = VerticalBarCell(edge: HorizontalEdge.left, rect: Rect.fromLTRB(24, 84, 72, 132));
      // 469 - 72 - 8.
      expect(left.tooltipMaxWidth(469), 389);
      expect(left.tooltipMaxWidth(951), 871, reason: 'it follows the window width');
    });

    test('is never negative', () {
      const right = VerticalBarCell(edge: HorizontalEdge.right, rect: Rect.fromLTRB(4, 0, 52, 48));
      expect(right.tooltipMaxWidth(951), 0);
      const left = VerticalBarCell(edge: HorizontalEdge.left, rect: Rect.fromLTRB(24, 84, 72, 132));
      expect(left.tooltipMaxWidth(76), 0);
    });
  });
}

Widget _customCell(BuildContext context, VerticalBarCell cell) => const SizedBox();
