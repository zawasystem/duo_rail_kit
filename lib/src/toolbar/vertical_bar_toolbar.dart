/// [VerticalBarPage] and [VerticalBarShell], one library because they share a private protocol. A page below
/// a shell reads the shell's decisions from [_ShellScope] and reports its controls to the shell's
/// [_ShellRegistry] (`register`, `unregister`, `notify`). The shell picks the owner page by its route, tickers
/// and mount order, and builds that page's cells with its builders, themes and invoke gates.
///
/// @docImport '../layout/rail_layout.dart';
/// @docImport '../layout/rail_placement.dart';
/// @docImport '../layout/side_status_bar_insets.dart';
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoSheetRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/geometry.dart';
import '../core/horizontal_edge.dart';
import '../edge/vertical_bar_edge.dart';
import '../layout/rail_side_row.dart';
import 'shared/cell_owner.dart';
import 'shared/column_cells.dart';
import 'shared/column_menus.dart';
import 'shared/column_traversal.dart';
import 'shared/route_status.dart';
import 'shell_geometry.dart';
import 'vertical_bar_action.dart';
import 'vertical_bar_column.dart';

part 'page/vertical_bar_page.dart';
part 'shell/column_layer.dart';
part 'shell/debug_stats.dart';
part 'shell/rail_end.dart';
part 'shell/shell_layout.dart';
part 'shell/shell_registry.dart';
part 'shell/vertical_bar_shell.dart';
