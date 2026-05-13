import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../graph_models.dart';

/// Renders the force-directed graph: edges via a custom painter,
/// positioned nodes stacked on top.
class ObsidianGraphView extends StatelessWidget {
  const ObsidianGraphView({
    super.key,
    required this.nodes,
    required this.edges,
    required this.zoomScale,
    required this.selectedNode,
    required this.onTapNode,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBookmark,
    required this.onLocalGraph,
    required this.palette,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final double zoomScale;
  final int? selectedNode;
  final ValueChanged<int> onTapNode;
  final ValueChanged<int> onDragStart;
  final void Function(int, Offset) onDragUpdate;
  final ValueChanged<int> onDragEnd;
  final ValueChanged<int> onBookmark;
  final ValueChanged<int> onLocalGraph;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final canvasCentre =
            Offset(canvasSize.width / 2, canvasSize.height / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: canvasSize,
              painter: ObsidianEdgePainter(
                nodes: nodes,
                edges: edges,
                centre: canvasCentre,
                palette: palette,
                selectedNode: selectedNode,
              ),
            ),
            for (var i = 0; i < nodes.length; i++)
              PositionedNode(
                node: nodes[i],
                canvasCentre: canvasCentre,
                palette: palette,
                zoomScale: zoomScale,
                isSelected: selectedNode == i,
                onTap: () => onTapNode(i),
                onDragStart: () => onDragStart(i),
                onDragUpdate: (delta) => onDragUpdate(i, delta),
                onDragEnd: () => onDragEnd(i),
                onBookmark: () => onBookmark(i),
                onLocalGraph: () => onLocalGraph(i),
              ),
          ],
        );
      },
    );
  }
}

/// A single node in the graph, positioned absolutely.
class PositionedNode extends StatelessWidget {
  const PositionedNode({
    super.key,
    required this.node,
    required this.canvasCentre,
    required this.palette,
    required this.zoomScale,
    required this.isSelected,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBookmark,
    required this.onLocalGraph,
  });

  final GraphNode node;
  final Offset canvasCentre;
  final NoeticaPalette palette;
  final double zoomScale;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onBookmark;
  final VoidCallback onLocalGraph;

  static const double _expandThreshold = 1.8;

  @override
  Widget build(BuildContext context) {
    final screenPos = canvasCentre + node.pos;
    final r = node.radius;
    final color = node.color;

    final expanded = zoomScale >= _expandThreshold && !node.isCentre;
    final showLabel = node.isCentre || isSelected || expanded;

    final cardW = expanded ? 160.0 : 0.0;
    final cardH = expanded ? 36.0 : 0.0;
    final hitSize = expanded
        ? math.max(cardW, 44.0)
        : math.max(r * 2 + 16, 44.0);
    final hitHeight = expanded ? math.max(cardH + 8, 44.0) : hitSize;

    if (expanded) {
      return Positioned(
        left: screenPos.dx - hitSize / 2,
        top: screenPos.dy - hitHeight / 2,
        width: hitSize,
        height: hitHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onBookmark,
          onPanStart: (_) => onDragStart(),
          onPanUpdate: (d) => onDragUpdate(d.delta),
          onPanEnd: (_) => onDragEnd(),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: cardW),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color.withOpacity(isSelected ? 0.9 : 0.5),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.isBookmarked)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.bookmark,
                          size: 12, color: Color(0xFFF59E0B)),
                    ),
                  Flexible(
                    child: Text(
                      node.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (node.linkCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${node.linkCount}',
                        style: TextStyle(
                          color: color.withOpacity(0.6),
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: screenPos.dx - hitSize / 2,
      top: screenPos.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onBookmark,
        onDoubleTap: onLocalGraph,
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (d) => onDragUpdate(d.delta),
        onPanEnd: (_) => onDragEnd(),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: r * 2 + (isSelected ? 12 : 6),
              height: r * 2 + (isSelected ? 12 : 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isSelected ? 0.5 : 0.2),
                    blurRadius: isSelected ? 20 : 10,
                    spreadRadius: isSelected ? 4 : 1,
                  ),
                ],
              ),
            ),
            Container(
              width: r * 2,
              height: r * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: node.isCentre
                    ? color
                    : color.withOpacity(isSelected ? 1.0 : 0.85),
                border: Border.all(
                  color: color.withOpacity(0.9),
                  width: node.isCentre ? 2 : 1.5,
                ),
              ),
              child: node.isBookmarked
                  ? const Center(
                      child: Icon(Icons.bookmark,
                          size: 10, color: Colors.white),
                    )
                  : null,
            ),
            if (showLabel)
              Positioned(
                top: hitSize / 2 + r + 4,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: node.isCentre ? 120 : 100,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.bg.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: node.isCentre ? 12 : 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints edges between nodes and ambient dust particles.
class ObsidianEdgePainter extends CustomPainter {
  ObsidianEdgePainter({
    required this.nodes,
    required this.edges,
    required this.centre,
    required this.palette,
    required this.selectedNode,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Offset centre;
  final NoeticaPalette palette;
  final int? selectedNode;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final a = nodes[edge.from];
      final b = nodes[edge.to];
      final posA = centre + a.pos;
      final posB = centre + b.pos;

      final isHighlighted = selectedNode != null &&
          (edge.from == selectedNode || edge.to == selectedNode);

      final color = b.color;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.5 : 1.2
        ..color = color.withOpacity(isHighlighted ? 0.75 : 0.35);

      canvas.drawLine(posA, posB, paint);
    }

    final rng = math.Random(7);
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      dotPaint.color =
          palette.muted.withOpacity(0.04 + rng.nextDouble() * 0.04);
      canvas.drawCircle(Offset(x, y), 1.0 + rng.nextDouble() * 1.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ObsidianEdgePainter old) => true;
}
