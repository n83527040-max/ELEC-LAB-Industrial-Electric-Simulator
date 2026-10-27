import 'dart:math' as math;

/// Serializable point in board coordinates. It intentionally has no Flutter
/// dependency so the electrical core can be tested as pure Dart.
class BoardPoint {
  const BoardPoint(this.x, this.y);

  final double x;
  final double y;

  static const zero = BoardPoint(0, 0);

  BoardPoint operator +(BoardPoint other) =>
      BoardPoint(x + other.x, y + other.y);

  BoardPoint operator -(BoardPoint other) =>
      BoardPoint(x - other.x, y - other.y);

  BoardPoint operator *(double factor) => BoardPoint(x * factor, y * factor);

  double distanceTo(BoardPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  BoardPoint rotate(double quarterTurns) {
    final turns = ((quarterTurns.round() % 4) + 4) % 4;
    return switch (turns) {
      1 => BoardPoint(-y, x),
      2 => BoardPoint(-x, -y),
      3 => BoardPoint(y, -x),
      _ => this,
    };
  }

  Map<String, double> toJson() => <String, double>{'x': x, 'y': y};

  factory BoardPoint.fromJson(Map<String, dynamic> json) {
    final x = json['x'];
    final y = json['y'];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
      throw const FormatException('Invalid board point.');
    }
    return BoardPoint(x.toDouble(), y.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is BoardPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'BoardPoint($x, $y)';
}
