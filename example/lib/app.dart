import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/material.dart';

const _ink = Color(0xFF142F38);
const _teal = Color(0xFF087F73);
const _muted = Color(0xFF526D72);
const _paper = Color(0xFFF3F7F6);
const _line = Color(0xFFDFE9E6);

ThemeData _theme() => ThemeData(
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.fromSeed(seedColor: _teal).copyWith(primary: _teal, surface: Colors.white, onSurface: _ink),
  scaffoldBackgroundColor: _paper,
  textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto', bodyColor: _ink, displayColor: _ink),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFD6F1E8),
    selectedIconTheme: IconThemeData(color: _teal),
    unselectedIconTheme: IconThemeData(color: _muted),
    selectedLabelTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.w700, color: _teal),
    unselectedLabelTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: _muted),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFD6F1E8),
    labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontSize: 12, color: _ink)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _teal,
    foregroundColor: Colors.white,
    elevation: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _paper,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
  ),
);

/// Runs the example using the actual window and native edge.
class DuoRailExampleApp extends StatelessWidget {
  const DuoRailExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Duo Rail Kit',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    builder: (context, child) => VerticalBarEdge(
      // Read the native edge before adjusting the root safe area.
      child: SideStatusBarInsets(child: child ?? const SizedBox.shrink()),
    ),
    home: const _DemoShell(),
  );
}

/// Renders labelled, simulated layouts for tests and local previews.
///
/// Bypasses the native plugin. Set the test view's logical size to [size].
class DuoRailPreviewApp extends StatelessWidget {
  const DuoRailPreviewApp({
    super.key,
    required this.size,
    required this.safeArea,
    this.edge,
    this.statusBarHidden = false,
    this.label = 'Layout preview',
    this.textScale = 1,
    this.viewInsets = EdgeInsets.zero,
    this.textDirection = TextDirection.ltr,
    this.topBar,
    this.verticalBar,
  });

  final Size size;
  final EdgeInsets safeArea;
  final HorizontalEdge? edge;
  final bool statusBarHidden;

  /// Simulated system bar regions. They apply only when their view sizes match [size] and a [topBar]'s safeTop
  /// matches the top safe area; otherwise the readout shows none and the app bar stays below the safe area.
  final TopBarRegion? topBar;
  final VerticalBarRegion? verticalBar;
  final String label;
  final double textScale;
  final EdgeInsets viewInsets;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Duo Rail Kit · simulated layout',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: safeArea.copyWith(bottom: viewInsets.bottom > 0 ? 0 : safeArea.bottom),
        viewPadding: safeArea,
        viewInsets: viewInsets,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: textDirection,
        child: VerticalBarEdgeScope(
          edge: edge,
          statusBarHidden: statusBarHidden,
          // Same order as VerticalBarEdge builds: the edge scope, then the region scope.
          child: BarRegionScope(
            topBar: topBar,
            verticalBar: verticalBar,
            child: SideStatusBarInsets(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    ),
    home: _DemoShell(previewLabel: label),
  );
}

const List<({IconData icon, IconData selectedIcon, String label, String title})> _destinations = [
  (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Layout', title: 'Overview'),
  (icon: Icons.touch_app_outlined, selectedIcon: Icons.touch_app_rounded, label: 'State', title: 'State lab'),
  (icon: Icons.code_rounded, selectedIcon: Icons.code_rounded, label: 'About', title: 'About the kit'),
];

class _DemoShell extends StatefulWidget {
  const _DemoShell({this.previewLabel});
  final String? previewLabel;

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

/// The numbers of rail tabs the State lab offers; tabs after the third are placeholders.
const List<int> _railTabCounts = [3, 5, 6, 7];

class _DemoShellState extends State<_DemoShell> {
  int _selected = 0;
  int _railTabs = 3;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final rail = RailLayout.of(context, showsRailByWidth: (width) => width >= 600, railWidth: 80);
    // The content pane in window coordinates, as TopBarRegion.paddingFor expects.
    final pane = rail.contentRect(data.size);
    final metrics = _LayoutMetrics(
      placement: rail.placement,
      occupiedWidth: rail.occupiedWidth,
      top: data.padding.top,
      addedTop: SideStatusBarInsets.addedOf(context).top,
      // Read where the window's top padding is intact; null on other screens and stale samples.
      topBar: TopBarRegion.of(context),
      verticalBar: VerticalBarRegion.of(context),
    );
    // Keep the content wrappers mounted to preserve state when placement changes.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: VerticalBarShell(
        railEdge: rail.edge,
        // reservesBack stays false: the detail page is a root push with its own column, and reserving a back control
        // would lower the rail on every tab.
        rail: SizedBox(
          key: const ValueKey('rail-column'),
          width: rail.occupiedWidth,
          child: Padding(
            padding: EdgeInsets.only(bottom: data.viewInsets.bottom),
            // railPaddingOf reads the shell above, so it needs a context below it.
            child: Builder(
              builder: (context) => MediaQuery(
                data: data.copyWith(
                  padding: VerticalBarShell.railPaddingOf(context, rail.centredSafeArea),
                ),
                child: NavigationRail(
                  key: const ValueKey('navigation-rail'),
                  selectedIndex: _selected,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  minWidth: rail.width,
                  groupAlignment: rail.followsSystemBar ? 1 : 0,
                  scrollable: true,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: _railLabel(destination.label),
                      ),
                    for (var tab = _destinations.length + 1; tab <= _railTabs; tab++)
                      NavigationRailDestination(
                        icon: const Icon(Icons.crop_square_rounded),
                        label: _railLabel('Tab $tab'),
                        disabled: true,
                      ),
                  ],
                  // Tells the shell where the destinations start, so the cells above them end 12 higher.
                  trailing: const VerticalBarRailEnd(),
                ),
              ),
            ),
          ),
        ),
        content: RailSideFab(
          enabled: rail.followsSystemBar,
          child: MediaQuery(
            data: rail.removeRailEdge(data),
            child: _DemoContent(
              selected: _selected,
              onSelected: _select,
              railTabs: _railTabs,
              onRailTabsChanged: (value) => setState(() => _railTabs = value),
              metrics: metrics,
              pane: pane,
              previewLabel: widget.previewLabel,
            ),
          ),
        ),
      ),
    );
  }

  void _select(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selected = value);
  }

  static Widget _railLabel(String label) => Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);
}

class _LayoutMetrics {
  const _LayoutMetrics({
    required this.placement,
    required this.occupiedWidth,
    required this.top,
    required this.addedTop,
    required this.topBar,
    required this.verticalBar,
  });
  final RailPlacement? placement;
  final double occupiedWidth;
  final double top;
  final double addedTop;
  final TopBarRegion? topBar;
  final VerticalBarRegion? verticalBar;

  String get side => switch (placement?.edge) {
    HorizontalEdge.left => 'Left rail',
    HorizontalEdge.right => 'Right rail',
    null => 'Bottom bar',
  };
  String get source => placement?.followsSystemBar == true ? 'System edge' : 'Window width';

  String get topBarSize => _sizeOf(topBar?.rect);
  String get topBarDetail {
    final region = topBar;
    return region == null
        ? 'No band beside the status bar'
        : '${_position(region.rect)} · safe top ${_points(region.safeTop)}';
  }

  String get verticalBarSize => _sizeOf(verticalBar?.rect);
  String get verticalBarDetail {
    final region = verticalBar;
    if (region == null) {
      return 'No vertical bar region';
    }
    final topBarTop = region.topBarTop;
    return '${region.edge == HorizontalEdge.left ? 'Left' : 'Right'} edge · ${_position(region.rect)}'
        '${topBarTop == null ? '' : ' · top bar top ${_points(topBarTop)}'}';
  }

  static String _sizeOf(Rect? rect) => rect == null ? 'None' : '${_points(rect.width)} × ${_points(rect.height)} px';

  static String _position(Rect rect) =>
      'x ${_points(rect.left)}–${_points(rect.right)}, y ${_points(rect.top)}–${_points(rect.bottom)}';

  /// Whole logical pixels without decimals; pixel-aligned fractions with one decimal.
  static String _points(double value) => value == value.roundToDouble() ? '${value.toInt()}' : value.toStringAsFixed(1);
}

class _DemoContent extends StatefulWidget {
  const _DemoContent({
    required this.selected,
    required this.onSelected,
    required this.railTabs,
    required this.onRailTabsChanged,
    required this.metrics,
    required this.pane,
    this.previewLabel,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final int railTabs;
  final ValueChanged<int> onRailTabsChanged;
  final _LayoutMetrics metrics;
  final Rect pane;
  final String? previewLabel;

  @override
  State<_DemoContent> createState() => _DemoContentState();
}

class _DemoContentState extends State<_DemoContent> {
  final _note = TextEditingController();
  final _scroll = ScrollController();
  int _taps = 0;

  @override
  void didUpdateWidget(_DemoContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VerticalBarPage(
    // Beside a system rail with a vertical bar column, VerticalBarShell draws these in the column above the rail.
    actions: [
      VerticalBarAction(
        id: 'reset-taps',
        icon: const Icon(Icons.restart_alt_rounded),
        label: 'Reset counter',
        onPressed: (_) => _reset(),
      ),
      VerticalBarAction(
        id: 'about',
        icon: const Icon(Icons.info_outline_rounded),
        label: 'About the kit',
        onPressed: (_) => widget.onSelected(2),
      ),
    ],
    builder: _scaffold,
  );

  Widget _scaffold(BuildContext context, VerticalBarSlots slots) => Scaffold(
    key: const ValueKey('content-scaffold'),
    appBar: _DemoAppBar(
      band: widget.metrics.topBar,
      pane: widget.pane,
      title: _destinations[widget.selected].title,
      // As on the detail page: an iOS AppBar would centre the title once the actions leave it.
      centerTitle: slots.active ? false : null,
      actions: slots.active
          ? const []
          : [
              IconButton(
                key: const ValueKey('reset-taps'),
                tooltip: 'Reset counter',
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
              IconButton(
                tooltip: 'About the kit',
                onPressed: () => widget.onSelected(2),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
    ),
    floatingActionButtonLocation: RailSideFab.locationOf(context),
    floatingActionButton: FloatingActionButton(
      key: const ValueKey('add-tap'),
      tooltip: 'Add a tap',
      onPressed: _increment,
      child: const Icon(Icons.add_rounded),
    ),
    bottomNavigationBar: widget.metrics.placement == null
        ? NavigationBar(
            selectedIndex: widget.selected,
            onDestinationSelected: widget.onSelected,
            destinations: [
              for (final destination in _destinations)
                DefaultTextStyle.merge(
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  child: NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
                ),
            ],
          )
        : null,
    // The app bar keeps the viewport's top below it. SafeArea keeps the viewport above the bottom inset, so caret,
    // focus and accessibility reveals stay clear of the home indicator, while the content is painted past it and is
    // not clipped above the home indicator. Content scrolled up passes under the opaque app bar.
    body: SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('content-scroll'),
        controller: _scroll,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(previewLabel: widget.previewLabel),
                const SizedBox(height: 28),
                switch (widget.selected) {
                  0 => _overview(),
                  1 => _stateLab(),
                  _ => _about(),
                },
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _increment() => setState(() => _taps++);

  void _reset() => setState(() => _taps = 0);

  void _openDetail() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (context) => _DetailPage(previewLabel: widget.previewLabel)));

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _HeroCard(placement: widget.metrics.placement),
      const SizedBox(height: 20),
      _MetricsCards(metrics: widget.metrics),
      const SizedBox(height: 24),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow('SAME CONTENT. NEW PLACEMENT.'),
            const SizedBox(height: 12),
            const Text('Your place stays yours.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Rotate, resize, or change Split View. The navigation moves; your input and counter stay with you.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CountLabel(count: _taps),
                TextButton.icon(
                  onPressed: () => widget.onSelected(1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Open state lab'),
                ),
                TextButton.icon(
                  key: const ValueKey('open-detail'),
                  onPressed: _openDetail,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('Open detail'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'A small Flutter example. No account, network, or saved personal data.',
        style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
      ),
    ],
  );

  Widget _stateLab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('STATE LAB'),
      const SizedBox(height: 10),
      const Text(
        'Move the rail.\nKeep the moment.',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.15),
      ),
      const SizedBox(height: 12),
      const Text(
        'Add a few taps and write a note. Then rotate or resize this window. Both values live in the content widget.',
        style: TextStyle(color: _muted, height: 1.5),
      ),
      const SizedBox(height: 24),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow('YOUR SESSION'),
            const SizedBox(height: 12),
            _CountLabel(count: _taps, large: true),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(onPressed: _increment, icon: const Icon(Icons.add), label: const Text('Add a tap')),
                TextButton(onPressed: _reset, child: const Text('Reset counter')),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('session-note'),
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'A note to keep', hintText: 'Type, then rotate or resize.'),
            ),
            const SizedBox(height: 12),
            const Text('Kept in memory for this session only.', style: TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow('RAIL TABS'),
            const SizedBox(height: 12),
            const Text(
              'Add placeholder tabs to the rail. Beside a system rail, the actions in the vertical bar column above it '
              'move to the overflow menu when they no longer fit.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              key: const ValueKey('rail-tabs'),
              showSelectedIcon: false,
              segments: [
                for (final count in _railTabCounts) ButtonSegment<int>(value: count, label: Text('$count')),
              ],
              selected: {widget.railTabs},
              onSelectionChanged: (selection) => widget.onRailTabsChanged(selection.single),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _MetricsCards(metrics: widget.metrics),
    ],
  );

  Widget _about() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Eyebrow('SMALL PIECES, ONE LAYOUT'),
      SizedBox(height: 10),
      Text('Let the system lead.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      SizedBox(height: 20),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Rule('01', 'Read the edge first', 'VerticalBarEdge wraps SideStatusBarInsets at the root.'),
            _Rule(
              '02',
              'Use the available window',
              'The system edge wins. Without one, a rail appears at 600 logical pixels.',
            ),
            _Rule(
              '03',
              'Share the status column',
              'The system rail uses 96 pixels. centredRailSafeArea keeps controls clear of the status display.',
            ),
            _Rule(
              '04',
              'Keep the tree steady',
              'VerticalBarShell and RailSideFab always wrap the same content. Only their values change.',
            ),
            _Rule(
              '05',
              'Leave room for an action',
              'RailSideFab keeps the action 24 pixels above the content bottom beside a system rail.',
            ),
            _Rule(
              '06',
              'Use the band beside the status bar',
              'Where TopBarRegion reports a band, the toolbar row moves into it. Elsewhere it sits below the safe area.',
            ),
          ],
        ),
      ),
      SizedBox(height: 16),
      Text(
        'The native edge requires a supported iOS version and device. Other environments use width-based navigation. '
        'Status-bar visibility refreshes with geometry, traits, or app resume; it is not a continuous visibility stream.',
        style: TextStyle(color: _muted, height: 1.5),
      ),
    ],
  );
}

/// The app bar of the content pane, and of the detail page with the whole window as its pane. Its toolbar row moves
/// into the system's top band when one is reported.
///
/// The same widgets are built with or without a band; only padding and heights change, so the app bar and its
/// actions, including their focus, are not recreated when a band appears or disappears.
class _DemoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DemoAppBar({
    required this.band,
    required this.pane,
    required this.title,
    required this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
  });

  /// Read with TopBarRegion.of where the window's top padding is intact.
  final TopBarRegion? band;

  /// The content pane in window coordinates.
  final Rect pane;
  final String title;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;

  // The Scaffold adds the top safe area to this height. A band lies inside that area, so it adds nothing.
  @override
  Size get preferredSize => Size.fromHeight(band == null ? kToolbarHeight : 0);

  @override
  Widget build(BuildContext context) {
    final band = this.band;
    final data = MediaQuery.of(context);
    return MediaQuery(
      // AppBar pads its toolbar by the safe area; in the band, that padding places the row beside the status display.
      data: band == null ? data : data.copyWith(padding: band.paddingFor(pane)),
      child: AppBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        centerTitle: centerTitle,
        toolbarHeight: band?.rect.height ?? kToolbarHeight,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: _line)),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [...actions, const SizedBox(width: 4)],
      ),
    );
  }
}

/// Actions added by the More actions switch, for ten in all: in the inner landscape column, back, seven actions, and
/// the overflow cell.
const List<({String id, IconData icon, String label})> _extraActions = [
  (id: 'copy-link', icon: Icons.link_rounded, label: 'Copy link'),
  (id: 'bookmark', icon: Icons.bookmark_border_rounded, label: 'Bookmark'),
  (id: 'download', icon: Icons.download_rounded, label: 'Download'),
  (id: 'print', icon: Icons.print_outlined, label: 'Print'),
  (id: 'edit', icon: Icons.edit_outlined, label: 'Edit'),
  (id: 'archive', icon: Icons.archive_outlined, label: 'Archive'),
  (id: 'report', icon: Icons.flag_outlined, label: 'Report'),
];

/// A full-window pushed page. Where iOS reports a vertical bar column, VerticalBarPage draws its back control and
/// actions there, at UIKit's positions; elsewhere its app bar keeps them.
class _DetailPage extends StatefulWidget {
  const _DetailPage({this.previewLabel});
  final String? previewLabel;

  @override
  State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> {
  bool _favorite = false;
  bool _moreActions = false;
  String _lastAction = 'None yet';

  @override
  Widget build(BuildContext context) => VerticalBarPage(
    // Stable ids keep each cell's state when actions are added or move to the overflow menu.
    actions: [
      VerticalBarAction(
        id: 'share',
        icon: const Icon(Icons.ios_share_rounded),
        label: 'Share',
        // The anchor is where a share sheet or popover opens from.
        onPressed: (invocation) => _record('Share', invocation),
      ),
      VerticalBarAction(
        id: 'favorite',
        icon: Icon(_favorite ? Icons.star_rounded : Icons.star_outline_rounded),
        label: 'Favorite',
        selected: _favorite,
        onPressed: (_) => _toggleFavorite(),
      ),
      VerticalBarAction(
        id: 'manage',
        icon: const Icon(Icons.tune_rounded),
        label: 'Manage',
        menuItems: [
          VerticalBarMenuItem(
            label: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            destructive: true,
            onSelected: _delete,
          ),
        ],
      ),
      if (_moreActions)
        for (final extra in _extraActions)
          VerticalBarAction(
            id: extra.id,
            icon: Icon(extra.icon),
            label: extra.label,
            onPressed: (invocation) => _record(extra.label, invocation),
          ),
    ],
    builder: (context, slots) => Scaffold(
      appBar: _DemoAppBar(
        // Read here, above the Scaffold, where the window's top padding is intact.
        band: TopBarRegion.of(context),
        pane: Offset.zero & MediaQuery.sizeOf(context),
        title: 'Detail',
        automaticallyImplyLeading: !slots.backInColumn,
        // UIKit leaves the title at the leading edge; an iOS AppBar centres a title with fewer than two actions.
        centerTitle: slots.active ? false : null,
        // While the column is used, it holds every action, including those in its overflow menu.
        actions: slots.active ? const [] : _appBarActions(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('detail-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: _DetailBody(
                previewLabel: widget.previewLabel,
                inColumn: slots.active,
                moreActions: _moreActions,
                onMoreActionsChanged: (value) => setState(() => _moreActions = value),
                lastAction: _lastAction,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// The same actions for the app bar, where no column applies.
  List<Widget> _appBarActions() => [
    IconButton(
      tooltip: 'Share',
      onPressed: () => _record('Share', null),
      icon: const Icon(Icons.ios_share_rounded),
    ),
    IconButton(
      tooltip: 'Favorite',
      isSelected: _favorite,
      onPressed: _toggleFavorite,
      icon: Icon(_favorite ? Icons.star_rounded : Icons.star_outline_rounded),
    ),
    PopupMenuButton<void>(
      tooltip: 'Manage',
      icon: const Icon(Icons.tune_rounded),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: _delete,
          child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
    if (_moreActions)
      PopupMenuButton<void>(
        tooltip: 'More actions',
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) => [
          for (final extra in _extraActions)
            PopupMenuItem<void>(onTap: () => _record(extra.label, null), child: Text(extra.label)),
        ],
      ),
  ];

  /// Shows where [label] was invoked from: a column cell, the overflow cell, or the app bar (null).
  void _record(String label, VerticalBarInvocation? invocation) => setState(() {
    _lastAction = invocation == null
        ? '$label from the app bar'
        : '$label from ${_LayoutMetrics._position(invocation.anchor)}'
              '${invocation.fromOverflowMenu ? ' via the overflow menu' : ''}';
  });

  void _toggleFavorite() => setState(() => _favorite = !_favorite);

  void _delete() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Delete chosen. The example deletes nothing.')));
}

class _DetailBody extends StatefulWidget {
  const _DetailBody({
    required this.previewLabel,
    required this.inColumn,
    required this.moreActions,
    required this.onMoreActionsChanged,
    required this.lastAction,
  });
  final String? previewLabel;
  final bool inColumn;
  final bool moreActions;
  final ValueChanged<bool> onMoreActionsChanged;
  final String lastAction;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  // Kept below VerticalBarPage, so it shows that the page keeps its state when the column appears or disappears.
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Header(previewLabel: widget.previewLabel),
      const SizedBox(height: 28),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow('PUSHED PAGE'),
            const SizedBox(height: 12),
            const Text('Back and actions follow the bar.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              widget.inColumn
                  ? 'They are in the vertical bar column, where UIKit puts them. The app bar keeps the title.'
                  : 'No vertical bar column applies here, so they stay in the app bar.',
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$_taps ${_taps == 1 ? 'tap' : 'taps'}',
                  key: const ValueKey('detail-taps'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _teal),
                ),
                FilledButton.icon(
                  key: const ValueKey('detail-add-tap'),
                  onPressed: () => setState(() => _taps++),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a tap'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Its own Material, so that the tile's ink shows above the panel's background.
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                key: const ValueKey('more-actions'),
                contentPadding: EdgeInsets.zero,
                value: widget.moreActions,
                onChanged: widget.onMoreActionsChanged,
                title: const Text('More actions', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Ten actions in all. Those that do not fit move to an overflow menu.',
                  style: TextStyle(color: _muted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _Eyebrow('LAST ACTION'),
            const SizedBox(height: 7),
            Text(
              widget.lastAction,
              key: const ValueKey('last-action'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({this.previewLabel});
  final String? previewLabel;

  @override
  Widget build(BuildContext context) {
    const brand = Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.all(Radius.circular(13))),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.view_sidebar_rounded, color: Colors.white, size: 24),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duo Rail Kit', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              SizedBox(height: 3),
              Text('Adaptive navigation, shared.', style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
    final badge = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: previewLabel == null ? const Color(0xFFDFF2EA) : const Color(0xFFFFEAC6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Text(
              previewLabel == null ? 'LIVE LAYOUT' : 'SIMULATED LAYOUT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: previewLabel == null ? _teal : const Color(0xFF745619),
              ),
            ),
          ),
        ),
        if (previewLabel != null) ...[
          const SizedBox(height: 6),
          Text(previewLabel!, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 600 && MediaQuery.textScalerOf(context).scale(1) < 1.5
          ? Row(
              children: [
                const Expanded(child: brand),
                const SizedBox(width: 16),
                badge,
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [brand, const SizedBox(height: 16), badge]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.placement});
  final RailPlacement? placement;

  static const _oneLineTitle = 'At home on every edge.';

  static bool _fitsOneLine(BuildContext context, String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final fits = !painter.didExceedMaxLines && painter.width <= width;
    painter.dispose();
    return fits;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final roomy = constraints.maxWidth >= 560 && scaler.scale(1) < 1.5;
        final titleStyle = TextStyle(
          fontSize: roomy ? 40 : 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
          letterSpacing: -0.8,
        );
        // Wide panes drop the forced line breaks where the title fits on one line in the platform font, and use a
        // shorter sketch, so a short landscape window such as the Duo inner display still shows the metrics.
        final oneLine = roomy && _fitsOneLine(context, _oneLineTitle, titleStyle, constraints.maxWidth - 232);
        final words = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BUILT FOR THE EDGES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: Color(0xFF82D5C0)),
            ),
            SizedBox(height: oneLine ? 10 : 14),
            Text(oneLine ? _oneLineTitle : 'At home\non every edge.', style: titleStyle),
            SizedBox(height: oneLine ? 12 : 16),
            Text(
              oneLine
                  ? 'One shared layout. The system sets the side.'
                  : 'One shared layout.\nThe system sets the side.',
              style: const TextStyle(color: Color(0xFFB5CCCF), height: 1.5),
            ),
          ],
        );
        return roomy
            ? Row(
                children: [
                  Expanded(child: words),
                  const SizedBox(width: 32),
                  _LayoutSketch(edge: placement?.edge, height: oneLine ? 104 : 158),
                ],
              )
            : words;
      },
    ),
  );
}

class _LayoutSketch extends StatelessWidget {
  const _LayoutSketch({required this.edge, required this.height});
  final HorizontalEdge? edge;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 200,
      height: height,
      child: CustomPaint(painter: _LayoutSketchPainter(edge)),
    ),
  );
}

class _LayoutSketchPainter extends CustomPainter {
  const _LayoutSketchPainter(this.edge);
  final HorizontalEdge? edge;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(15)),
      paint..color = const Color(0xFF2C4952),
    );
    final rail = edge == null
        ? Rect.fromLTWH(7, size.height - 30, size.width - 14, 23)
        : Rect.fromLTWH(edge == HorizontalEdge.left ? 7 : size.width - 35, 7, 28, size.height - 14);
    canvas.drawRRect(RRect.fromRectAndRadius(rail, const Radius.circular(9)), paint..color = const Color(0xFF82D5C0));
    final left = edge == HorizontalEdge.left ? 47.0 : 15.0;
    final width = size.width - (edge == null ? 30 : 62);
    // The page lines fill the space beside or above the rail.
    const top = 16.0;
    final span = (edge == null ? rail.top - 8 : size.height - 14) - top;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width * 0.6, 6), const Radius.circular(3)),
        paint..color = const Color(0xFF8DA9AF),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top + span * 0.18, width, span * 0.36), const Radius.circular(8)),
        paint..color = const Color(0xFF476670),
      );
    for (var i = 0; i < 3; i++) {
      final center = edge == null
          ? Offset(rail.left + 35 + i * 56, rail.center.dy)
          : Offset(rail.center.dx, rail.bottom - 18 - i * (rail.height - 36) / 2);
      canvas.drawCircle(center, 4, paint..color = _teal);
    }
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top + span * 0.68, width * 0.72, 5), const Radius.circular(3)),
        paint..color = const Color(0xFF617E86),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top + span * 0.84, width * 0.48, 5), const Radius.circular(3)),
        paint,
      );
  }

  @override
  bool shouldRepaint(_LayoutSketchPainter oldDelegate) => oldDelegate.edge != edge;
}

const _minMetricWidth = 220.0;

class _MetricsCards extends StatelessWidget {
  const _MetricsCards({required this.metrics});
  final _LayoutMetrics metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Up to three columns, each at least 220 wide so a value such as '509 × 48 px' stays on one line.
      final columns = MediaQuery.textScalerOf(context).scale(1) < 1.5
          ? ((constraints.maxWidth + 12) ~/ (_minMetricWidth + 12)).clamp(1, 3)
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Metric(
            width: width,
            icon: Icons.swap_horiz_rounded,
            title: 'PLACEMENT',
            value: metrics.side,
            detail: metrics.source,
          ),
          _Metric(
            width: width,
            icon: Icons.space_bar_rounded,
            title: 'RAIL WIDTH',
            value: '${metrics.occupiedWidth.toInt()} px',
            detail: metrics.placement == null ? 'Bottom navigation active' : 'One column, counted once',
          ),
          _Metric(
            width: width,
            icon: Icons.vertical_align_top_rounded,
            title: 'TOP SAFE AREA',
            value: '${metrics.top.toInt()} px',
            detail: metrics.addedTop > 0
                ? '${metrics.addedTop.toInt()} px added for breathing room'
                : 'Environment inset preserved',
          ),
          _Metric(
            width: width,
            icon: Icons.border_top_rounded,
            title: 'TOP BAR REGION',
            value: metrics.topBarSize,
            detail: metrics.topBarDetail,
          ),
          _Metric(
            width: width,
            icon: Icons.border_vertical_rounded,
            title: 'VERTICAL BAR REGION',
            value: metrics.verticalBarSize,
            detail: metrics.verticalBarDetail,
          ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: _Panel(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _teal, size: 22),
          const SizedBox(height: 14),
          _Eyebrow(title),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4)),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = 24});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
  );
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.count, this.large = false});
  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) => Text(
    '$count ${count == 1 ? 'tap' : 'taps'}',
    key: const ValueKey('tap-count'),
    style: TextStyle(fontSize: large ? 44 : 18, fontWeight: FontWeight.w700, color: _teal),
  );
}

class _Rule extends StatelessWidget {
  const _Rule(this.number, this.title, this.detail);
  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number / $title',
          style: const TextStyle(color: _teal, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(detail, style: const TextStyle(color: _muted, height: 1.5)),
      ],
    ),
  );
}
