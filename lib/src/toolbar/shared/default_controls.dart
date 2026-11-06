import 'package:flutter/material.dart';

import '../vertical_bar_action.dart';
import '../vertical_bar_column.dart';

/// The UIKit-sized default control: a 38 x 38 button with a 24 icon in a 48 x 48 target (logical pixels),
/// whatever the theme's density or IconButtonTheme. Material 3 only: IconButton ignores its style and
/// isSelected when `ThemeData.useMaterial3` is false.
final ButtonStyle _controlStyle = IconButton.styleFrom(
  minimumSize: const Size.square(VerticalBarColumn.buttonExtent),
  maximumSize: const Size.square(VerticalBarColumn.buttonExtent),
  padding: const EdgeInsets.all((VerticalBarColumn.buttonExtent - _iconSize) / 2),
  iconSize: _iconSize,
  tapTargetSize: MaterialTapTargetSize.padded,
  visualDensity: VisualDensity.standard,
);

const double _iconSize = 24;

class _DefaultControl extends StatelessWidget {
  const _DefaultControl({required this.cell, required this.tooltip, required this.icon, this.selected});

  final VerticalBarCell cell;
  final String tooltip;
  final Widget icon;
  final bool? selected;

  // An empty tooltip, possible only in release builds, adds no tooltip.
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    constraints: cell.tooltipConstraints(context),
    positionDelegate: cell.tooltipPosition,
    child: IconButton(
      onPressed: cell.invoke,
      isSelected: selected,
      iconSize: _iconSize,
      style: _controlStyle,
      icon: icon,
    ),
  );
}

class DefaultActionControl extends StatelessWidget {
  const DefaultActionControl({super.key, required this.action, required this.cell});

  final VerticalBarAction action;
  final VerticalBarCell cell;

  @override
  Widget build(BuildContext context) =>
      // Standard actions, the only ones drawn with this, always have an icon.
      _DefaultControl(cell: cell, tooltip: action.label, icon: action.icon!, selected: action.selected);
}

class DefaultBackControl extends StatelessWidget {
  const DefaultBackControl({super.key, required this.cell, required this.close});

  final VerticalBarCell cell;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return _DefaultControl(
      cell: cell,
      tooltip: close ? localizations.closeButtonTooltip : localizations.backButtonTooltip,
      icon: close ? const CloseButtonIcon() : const BackButtonIcon(),
    );
  }
}

class DefaultOverflowControl extends StatelessWidget {
  const DefaultOverflowControl({super.key, required this.cell});

  final VerticalBarCell cell;

  @override
  Widget build(BuildContext context) => _DefaultControl(
    cell: cell,
    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
    icon: const Icon(Icons.more_horiz),
  );
}
