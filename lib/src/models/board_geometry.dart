import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'component.dart';
import 'component_catalog.dart';
import 'geometry.dart';
import 'project.dart';
import 'wire.dart';

abstract final class BoardGeometry {
  static BoardPoint center(CircuitComponent component) {
    final size = ComponentCatalog.specOf(component.kind).size;
    return component.position +
        BoardPoint(size.width * component.scale / 2, size.height * component.scale / 2);
  }

  static BoardPoint terminalPosition(
    CircuitComponent component,
    String terminalId,
  ) {
    final spec = ComponentCatalog.specOf(component.kind);
    final terminal = spec.terminal(terminalId);
    final localCenter = BoardPoint(spec.size.width / 2, spec.size.height / 2);
    final delta = (terminal.position - localCenter) * component.scale;
    return center(component) + delta.rotate(component.rotation.toDouble());
  }

  static Rect bounds(CircuitComponent component, {double padding = 0}) {
    final spec = ComponentCatalog.specOf(component.kind);
    final half = BoardPoint(
      spec.size.width * component.scale / 2,
      spec.size.height * component.scale / 2,
    );
    final corners = <BoardPoint>[
      BoardPoint(-half.x, -half.y),
      BoardPoint(half.x, -half.y),
      BoardPoint(half.x, half.y),
      BoardPoint(-half.x, half.y),
    ].map((point) => center(component) + point.rotate(component.rotation.toDouble()));
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final point in corners) {
      left = math.min(left, point.x);
      right = math.max(right, point.x);
      top = math.min(top, point.y);
      bottom = math.max(bottom, point.y);
    }
    return Rect.fromLTRB(
      left - padding,
      top - padding,
      right + padding,
      bottom + padding,
    );
  }
}

abstract final class WireRouter {
  static List<BoardPoint> route(
    ElectricalProject project,
    CircuitWire wire,
  ) {
    final fromComponent = project.componentById(wire.from.componentId)!;
    final toComponent = project.componentById(wire.to.componentId)!;
    final start = BoardGeometry.terminalPosition(
      fromComponent,
      wire.from.terminalId,
    );
    final end = BoardGeometry.terminalPosition(toComponent, wire.to.terminalId);
    if (wire.routeStyle == WireRouteStyle.straight || wire.waypoints.isNotEmpty) {
      return _clean(<BoardPoint>[start, ...wire.waypoints, end]);
    }
    if (wire.routeStyle == WireRouteStyle.curved) {
      final distance = start.distanceTo(end);
      final bend = BoardPoint(
        (start.x + end.x) / 2,
        math.min(start.y, end.y) - math.min(60, distance * 0.2),
      );
      return <BoardPoint>[start, bend, end];
    }

    final midX = (start.x + end.x) / 2;
    final midY = (start.y + end.y) / 2;
    final obstacles = project.components
        .where(
          (item) => item.id != fromComponent.id && item.id != toComponent.id,
        )
        .map((item) => BoardGeometry.bounds(item, padding: 14))
        .toList(growable: false);
    final channelsX = <double>{midX};
    final channelsY = <double>{midY};
    for (final rect in obstacles) {
      channelsX.add((rect.left - 26).clamp(8.0, project.boardWidth - 8).toDouble());
      channelsX.add((rect.right + 26).clamp(8.0, project.boardWidth - 8).toDouble());
      channelsY.add((rect.top - 26).clamp(8.0, project.boardHeight - 8).toDouble());
      channelsY.add((rect.bottom + 26).clamp(8.0, project.boardHeight - 8).toDouble());
    }
    final candidates = <List<BoardPoint>>[
      <BoardPoint>[start, BoardPoint(start.x, end.y), end],
      <BoardPoint>[start, BoardPoint(end.x, start.y), end],
      for (final x in channelsX)
        <BoardPoint>[
          start,
          BoardPoint(x, start.y),
          BoardPoint(x, end.y),
          end,
        ],
      for (final y in channelsY)
        <BoardPoint>[
          start,
          BoardPoint(start.x, y),
          BoardPoint(end.x, y),
          end,
        ],
    ];
    candidates.sort(
      (a, b) => _score(a, obstacles).compareTo(_score(b, obstacles)),
    );
    return _clean(candidates.first);
  }

  static double _score(List<BoardPoint> points, List<Rect> obstacles) {
    var score = (points.length > 2 ? points.length - 2 : 0) * 9.0;
    for (var index = 0; index < points.length - 1; index++) {
      final a = points[index];
      final b = points[index + 1];
      score += a.distanceTo(b);
      for (final rect in obstacles) {
        if (_segmentIntersectsRect(a, b, rect)) score += 1500;
      }
    }
    return score;
  }

  static bool _segmentIntersectsRect(
    BoardPoint a,
    BoardPoint b,
    Rect rect,
  ) {
    if (rect.contains(Offset(a.x, a.y)) ||
        rect.contains(Offset(b.x, b.y))) {
      return true;
    }
    final edges = <List<BoardPoint>>[
      <BoardPoint>[
        BoardPoint(rect.left, rect.top),
        BoardPoint(rect.right, rect.top),
      ],
      <BoardPoint>[
        BoardPoint(rect.right, rect.top),
        BoardPoint(rect.right, rect.bottom),
      ],
      <BoardPoint>[
        BoardPoint(rect.right, rect.bottom),
        BoardPoint(rect.left, rect.bottom),
      ],
      <BoardPoint>[
        BoardPoint(rect.left, rect.bottom),
        BoardPoint(rect.left, rect.top),
      ],
    ];
    return edges.any(
      (edge) => _segmentsIntersect(a, b, edge[0], edge[1]),
    );
  }

  static bool _segmentsIntersect(
    BoardPoint a,
    BoardPoint b,
    BoardPoint c,
    BoardPoint d,
  ) {
    double cross(BoardPoint p, BoardPoint q, BoardPoint r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    final d1 = cross(a, b, c);
    final d2 = cross(a, b, d);
    final d3 = cross(c, d, a);
    final d4 = cross(c, d, b);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  static List<BoardPoint> _clean(List<BoardPoint> input) {
    final result = <BoardPoint>[];
    for (final point in input) {
      if (result.isEmpty || result.last != point) result.add(point);
    }
    for (var index = result.length - 2; index > 0; index--) {
      final a = result[index - 1];
      final b = result[index];
      final c = result[index + 1];
      final cross = (b.x - a.x) * (c.y - b.y) -
          (b.y - a.y) * (c.x - b.x);
      if (cross.abs() < 0.001) result.removeAt(index);
    }
    return result;
  }
}

