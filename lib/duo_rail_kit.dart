/// System-directed navigation rails, vertical bar toolbars, safe-area spacing, and FAB placement for iPhone Duo.
library;

// Physical edges.
export 'src/core/horizontal_edge.dart' show HorizontalEdge;

// Native vertical bar edge and system bar regions, sampled from iOS.
export 'src/edge/bar_regions.dart' show BarRegionScope, TopBarRegion, VerticalBarRegion;
export 'src/edge/vertical_bar_edge.dart' show VerticalBarEdge, VerticalBarEdgeScope;

// Safe-area spacing, rail placement, and FAB placement.
export 'src/layout/rail_layout.dart' show RailLayout;
export 'src/layout/rail_placement.dart' show RailPlacement;
export 'src/layout/rail_side_fab.dart' show RailSideFab, RailSideFabLocation;
export 'src/layout/rail_side_row.dart' show RailSideRow;
export 'src/layout/side_status_bar_insets.dart' show SideStatusBarInsets;

// Vertical bar toolbar.
export 'src/toolbar/vertical_bar_action.dart'
    show
        VerticalBarAction,
        VerticalBarActionCallback,
        VerticalBarCell,
        VerticalBarCellBuilder,
        VerticalBarInvocation,
        VerticalBarItemBuilder,
        VerticalBarMenuItem;
export 'src/toolbar/vertical_bar_column.dart' show VerticalBarColumn;
export 'src/toolbar/vertical_bar_toolbar.dart'
    show VerticalBarBack, VerticalBarPage, VerticalBarRailEnd, VerticalBarShell, VerticalBarSlots;
