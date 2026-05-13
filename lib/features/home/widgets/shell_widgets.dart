import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brand_glyph.dart';

const double kFloatingTabBarHeight = 52;
const double kFloatingTabBarMargin = 10;
const double kFloatingTabBarHorizontalInset = 16;
const double kFloatingFabSize = 52;
const double kFloatingFabGap = 10;
const double kFloatingTabBarReserve =
    kFloatingTabBarHeight + kFloatingTabBarMargin * 2;

class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Custom sidebar — `NavigationRail` doesn't support a "secondary" group of
/// non-selectable shortcuts, so we hand-build the layout instead.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    required this.extended,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onAdd,
    required this.journalSelected,
    required this.onJournal,
    required this.knowledgeSelected,
    required this.onKnowledge,
    required this.calendarSelected,
    required this.onCalendar,
    required this.toolsSelected,
    required this.onTools,
    required this.settingsSelected,
    required this.onSettings,
    required this.onPomodoro,
    required this.palette,
    required this.moreTabIndex,
  });

  final bool extended;
  final List<ShellDestination> destinations;
  final int selectedIndex;
  final int moreTabIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAdd;
  final bool journalSelected;
  final VoidCallback onJournal;
  final bool knowledgeSelected;
  final VoidCallback onKnowledge;
  final bool calendarSelected;
  final VoidCallback onCalendar;
  final bool toolsSelected;
  final VoidCallback onTools;
  final bool settingsSelected;
  final VoidCallback onSettings;
  final VoidCallback onPomodoro;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final tr = S.of(context)!;
    final width = extended ? 220.0 : 76.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: SizedBox(
        width: width,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 0),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    const BrandGlyph(size: 28),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      Text(
                        'NOETICA',
                        style: TextStyle(
                          color: palette.fg,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Skip the "Ещё" tab (mobile-only) on desktop sidebar.
              for (var i = 0; i < destinations.length; i++)
                if (i != moreTabIndex)
                  SidebarTile(
                    icon: destinations[i].icon,
                    selectedIcon: destinations[i].selectedIcon,
                    label: destinations[i].label,
                    selected: selectedIndex == i &&
                        !journalSelected &&
                        !knowledgeSelected &&
                        !calendarSelected &&
                        !toolsSelected &&
                        !settingsSelected,
                    extended: extended,
                    palette: palette,
                    onTap: () => onDestinationSelected(i),
                  ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 0,
                  vertical: 4,
                ),
                child: Divider(color: palette.line, height: 1),
              ),
              SidebarTile(
                icon: Icons.calendar_month_outlined,
                selectedIcon: Icons.calendar_month,
                label: tr.navCalendar,
                selected: calendarSelected,
                extended: extended,
                palette: palette,
                onTap: onCalendar,
              ),
              SidebarTile(
                icon: Icons.bookmark_border_outlined,
                selectedIcon: Icons.bookmark,
                label: tr.navJournal,
                selected: journalSelected,
                extended: extended,
                palette: palette,
                onTap: onJournal,
              ),
              SidebarTile(
                icon: Icons.account_tree_outlined,
                selectedIcon: Icons.account_tree,
                label: tr.navKnowledge,
                selected: knowledgeSelected,
                extended: extended,
                palette: palette,
                onTap: onKnowledge,
              ),
              SidebarTile(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
                label: tr.navAssistant,
                selected: toolsSelected,
                extended: extended,
                palette: palette,
                onTap: onTools,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 12,
                  vertical: 4,
                ),
                child: extended
                    ? FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(tr.taskNew),
                      )
                    : Center(
                        child: FloatingActionButton.small(
                          onPressed: onAdd,
                          child: const Icon(Icons.add),
                        ),
                      ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 0,
                  vertical: 4,
                ),
                child: Divider(color: palette.line, height: 1),
              ),
              SidebarTile(
                icon: Icons.timer_outlined,
                selectedIcon: Icons.timer,
                label: tr.pomodoroTitle,
                selected: false,
                extended: extended,
                palette: palette,
                onTap: onPomodoro,
              ),
              SidebarTile(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: tr.navSettings,
                selected: settingsSelected,
                extended: extended,
                palette: palette,
                onTap: onSettings,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarTile extends StatelessWidget {
  const SidebarTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? palette.fg : palette.muted;
    final bg = selected ? palette.surface : Colors.transparent;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 2),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: selected
              ? BorderSide(color: palette.line)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 12 : 0,
              vertical: extended ? 10 : 12,
            ),
            child: extended
                ? Row(
                    children: [
                      Icon(selected ? selectedIcon : icon, color: fg, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Tooltip(
                      message: label,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        color: fg,
                        size: 22,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Telegram-style floating mobile tab bar — capsule shape, fully rounded
/// on both sides, hovers over content with a soft shadow. Outer
/// margins are applied by the parent layout (a Row that places the
/// pentagon FAB inline to the right) — this widget only renders the
/// capsule itself.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    required this.palette,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final NoeticaPalette palette;
  final int selectedIndex;
  final List<ShellDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return PhysicalModel(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(kFloatingTabBarHeight / 2),
      // Backdrop blur + 72 % opaque surface lets content moving
      // underneath the capsule subtly show through, which is what
      // makes the bar read as "floating" on top instead of "stuck
      // to the bottom".
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kFloatingTabBarHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: kFloatingTabBarHeight,
            decoration: BoxDecoration(
              color: palette.surface.withOpacity(0.72),
              borderRadius: BorderRadius.circular(kFloatingTabBarHeight / 2),
              border: Border.all(
                color: palette.line.withOpacity(0.55),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: FloatingTabItem(
                      palette: palette,
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-tab item: icon + label. Uses the same Material icons as the
/// desktop sidebar. No InkWell / ripple / hover — the user explicitly
/// asked for a flat hit area, only the active tab is highlighted
/// (via colour + bold label).
class FloatingTabItem extends StatelessWidget {
  const FloatingTabItem({
    required this.palette,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NoeticaPalette palette;
  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.fg : palette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 1),
            Text(
              destination.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                height: 1.05,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pentagon-shaped FAB that mirrors the Noetica logo glyph. Sits
/// inline to the right of the floating tab bar capsule. No
/// InkWell / ripple — flat tap surface, just an explicit press
/// scale-down for tactile feedback.
class PentagonFab extends StatefulWidget {
  const PentagonFab({required this.palette, required this.onTap});

  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  State<PentagonFab> createState() => _PentagonFabState();
}

class _PentagonFabState extends State<PentagonFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: kFloatingFabSize,
          height: kFloatingFabSize,
          child: CustomPaint(
            painter: _PentagonPainter(
              fill: widget.palette.fg,
              stroke: widget.palette.line.withOpacity(0.6),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: widget.palette.bg,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a regular pentagon (point-up) with rounded vertices and a
/// soft drop shadow underneath, matching the Noetica brand glyph.
class _PentagonPainter extends CustomPainter {
  _PentagonPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Slightly inset radius so the stroke stays inside the canvas.
    final r = math.min(size.width, size.height) / 2 - 1;
    final path = _pentagonPath(cx, cy, r, cornerRadius: 6);

    // Shadow.
    canvas.drawShadow(path, Colors.black.withOpacity(0.6), 6, false);

    // Fill.
    canvas.drawPath(path, Paint()..color = fill);

    // Subtle border to match the capsule's 1 px line.
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Build a regular pentagon path (one vertex at the top) with
  /// rounded corners. We construct the polygon, then approximate
  /// rounded vertices by inserting two anchor points per corner and
  /// quadratic curves between them.
  Path _pentagonPath(
    double cx,
    double cy,
    double r, {
    double cornerRadius = 0,
  }) {
    final pts = <Offset>[
      for (var i = 0; i < 5; i++)
        Offset(
          cx + r * math.cos(-math.pi / 2 + i * 2 * math.pi / 5),
          cy + r * math.sin(-math.pi / 2 + i * 2 * math.pi / 5),
        ),
    ];

    final path = Path();
    if (cornerRadius <= 0) {
      path.moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      return path;
    }

    for (var i = 0; i < pts.length; i++) {
      final prev = pts[(i - 1 + pts.length) % pts.length];
      final curr = pts[i];
      final next = pts[(i + 1) % pts.length];

      final v1 = curr - prev;
      final v2 = next - curr;
      final l1 = v1.distance;
      final l2 = v2.distance;
      final d1 = math.min(cornerRadius, l1 / 2);
      final d2 = math.min(cornerRadius, l2 / 2);

      final p1 = curr - v1 * (d1 / l1); // entry anchor
      final p2 = curr + v2 * (d2 / l2); // exit anchor

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PentagonPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}

class MoreGridItem extends StatelessWidget {
  const MoreGridItem({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.fg.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: palette.fg, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.fg,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
