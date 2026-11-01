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
  });

  final Size size;
  final EdgeInsets safeArea;
  final HorizontalEdge? edge;
  final bool statusBarHidden;
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
          child: SideStatusBarInsets(child: child ?? const SizedBox.shrink()),
        ),
      ),
    ),
    home: _DemoShell(previewLabel: label),
  );
}

const List<({IconData icon, IconData selectedIcon, String label})> _destinations = [
  (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Layout'),
  (icon: Icons.touch_app_outlined, selectedIcon: Icons.touch_app_rounded, label: 'State'),
  (icon: Icons.code_rounded, selectedIcon: Icons.code_rounded, label: 'About'),
];

class _DemoShell extends StatefulWidget {
  const _DemoShell({this.previewLabel});
  final String? previewLabel;

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<_DemoShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final placement = RailPlacement.of(context, showsRailByWidth: (width) => width >= 600);
    final railSafeArea = RailPlacement.railSafeAreaOf(context, receivesAddedTop: false);
    final railWidth = placement?.followsSystemBar == true ? RailPlacement.statusColumnWidth : 80.0;
    final occupiedWidth = placement?.occupiedWidth(railSafeArea, railWidth) ?? 0.0;
    final metrics = _LayoutMetrics(
      placement: placement,
      occupiedWidth: occupiedWidth,
      top: data.padding.top,
      addedTop: SideStatusBarInsets.addedOf(context).top,
    );
    // Keep the content wrappers mounted to preserve state when placement changes.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: RailSideRow(
        railEdge: placement?.edge,
        rail: SizedBox(
          key: const ValueKey('rail-column'),
          width: occupiedWidth,
          child: Padding(
            padding: EdgeInsets.only(bottom: data.viewInsets.bottom),
            child: MediaQuery(
              data: data.copyWith(padding: placement?.centredRailSafeArea(railSafeArea) ?? railSafeArea),
              child: NavigationRail(
                key: const ValueKey('navigation-rail'),
                selectedIndex: _selected,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                minWidth: railWidth,
                groupAlignment: placement?.followsSystemBar == true ? 1 : 0,
                scrollable: true,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(
                        destination.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        content: RailSideFab(
          enabled: placement?.followsSystemBar ?? false,
          child: MediaQuery(
            data: data.removePadding(
              removeLeft: placement?.edge == HorizontalEdge.left,
              removeRight: placement?.edge == HorizontalEdge.right,
            ),
            child: _DemoContent(
              selected: _selected,
              onSelected: _select,
              metrics: metrics,
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
}

class _LayoutMetrics {
  const _LayoutMetrics({
    required this.placement,
    required this.occupiedWidth,
    required this.top,
    required this.addedTop,
  });
  final RailPlacement? placement;
  final double occupiedWidth;
  final double top;
  final double addedTop;

  String get side => switch (placement?.edge) {
    HorizontalEdge.left => 'Left rail',
    HorizontalEdge.right => 'Right rail',
    null => 'Bottom bar',
  };
  String get source => placement?.followsSystemBar == true ? 'System edge' : 'Window width';
}

class _DemoContent extends StatefulWidget {
  const _DemoContent({required this.selected, required this.onSelected, required this.metrics, this.previewLabel});
  final int selected;
  final ValueChanged<int> onSelected;
  final _LayoutMetrics metrics;
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
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('content-scaffold'),
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
    // Keep the viewport inside the safe area so caret, focus and accessibility reveals stay clear of the status bar,
    // but paint the content past it so the list is not clipped below the status bar or above the home indicator.
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
                TextButton(onPressed: () => setState(() => _taps = 0), child: const Text('Reset counter')),
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
              'The system rail uses 84 pixels. centredRailSafeArea keeps controls clear of the status display.',
            ),
            _Rule(
              '04',
              'Keep the tree steady',
              'RailSideRow and RailSideFab always wrap the same content. Only their values change.',
            ),
            _Rule(
              '05',
              'Leave room for an action',
              'RailSideFab keeps the action 24 pixels above the content bottom beside a system rail.',
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

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 560 && MediaQuery.textScalerOf(context).scale(1) < 1.5;
        final words = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BUILT FOR THE EDGES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: Color(0xFF82D5C0)),
            ),
            const SizedBox(height: 14),
            Text(
              'At home\non every edge.',
              style: TextStyle(
                fontSize: roomy ? 40 : 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'One shared layout.\nThe system sets the side.',
              style: TextStyle(color: Color(0xFFB5CCCF), height: 1.5),
            ),
          ],
        );
        return roomy
            ? Row(
                children: [
                  Expanded(child: words),
                  const SizedBox(width: 32),
                  _LayoutSketch(edge: placement?.edge),
                ],
              )
            : words;
      },
    ),
  );
}

class _LayoutSketch extends StatelessWidget {
  const _LayoutSketch({required this.edge});
  final HorizontalEdge? edge;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(width: 200, height: 158, child: CustomPaint(painter: _LayoutSketchPainter(edge))),
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
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 18, width * 0.6, 7), const Radius.circular(3)),
        paint..color = const Color(0xFF8DA9AF),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 39, width, 45), const Radius.circular(8)),
        paint..color = const Color(0xFF476670),
      );
    for (var i = 0; i < 3; i++) {
      final center = edge == null
          ? Offset(rail.left + 35 + i * 56, rail.center.dy)
          : Offset(rail.center.dx, rail.bottom - 22 - i * 36);
      canvas.drawCircle(center, 4, paint..color = _teal);
    }
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 95, width * 0.72, 5), const Radius.circular(3)),
        paint..color = const Color(0xFF617E86),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 108, width * 0.48, 5), const Radius.circular(3)),
        paint,
      );
  }

  @override
  bool shouldRepaint(_LayoutSketchPainter oldDelegate) => oldDelegate.edge != edge;
}

class _MetricsCards extends StatelessWidget {
  const _MetricsCards({required this.metrics});
  final _LayoutMetrics metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 540 && MediaQuery.textScalerOf(context).scale(1) < 1.5 ? 3 : 1;
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
