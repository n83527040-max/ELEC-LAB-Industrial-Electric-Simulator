import 'complex_number.dart';

/// Gaussian elimination with scaled partial pivoting. Returns null for a
/// singular or ill-conditioned network instead of inventing measurements.
abstract final class LinearSolver {
  static List<ComplexNumber>? solve(
    List<List<ComplexNumber>> matrix,
    List<ComplexNumber> rhs,
  ) {
    final n = rhs.length;
    if (n == 0) return <ComplexNumber>[];
    if (matrix.length != n ||
        matrix.any((row) => row.length != n) ||
        rhs.length != n) {
      throw ArgumentError('MNA matrix must be square.');
    }
    final a = List<List<ComplexNumber>>.generate(
      n,
      (row) => List<ComplexNumber>.from(matrix[row]),
      growable: false,
    );
    final b = List<ComplexNumber>.from(rhs);
    final scales = List<double>.generate(
      n,
      (row) => a[row].fold<double>(
        0,
        (maximum, value) =>
            value.magnitude > maximum ? value.magnitude : maximum,
      ),
    );

    for (var column = 0; column < n; column++) {
      var pivot = column;
      var best = -1.0;
      for (var row = column; row < n; row++) {
        final scale = scales[row] == 0 ? 1.0 : scales[row];
        final ratio = a[row][column].magnitude / scale;
        if (ratio > best) {
          best = ratio;
          pivot = row;
        }
      }
      if (a[pivot][column].magnitude < 1e-12) return null;
      if (pivot != column) {
        final row = a[pivot];
        a[pivot] = a[column];
        a[column] = row;
        final value = b[pivot];
        b[pivot] = b[column];
        b[column] = value;
        final scale = scales[pivot];
        scales[pivot] = scales[column];
        scales[column] = scale;
      }
      for (var row = column + 1; row < n; row++) {
        final factor = a[row][column] / a[column][column];
        a[row][column] = ComplexNumber.zero;
        for (var index = column + 1; index < n; index++) {
          a[row][index] = a[row][index] - factor * a[column][index];
        }
        b[row] = b[row] - factor * b[column];
      }
    }

    final result = List<ComplexNumber>.filled(n, ComplexNumber.zero);
    for (var row = n - 1; row >= 0; row--) {
      var value = b[row];
      for (var column = row + 1; column < n; column++) {
        value = value - a[row][column] * result[column];
      }
      if (a[row][row].magnitude < 1e-12) return null;
      result[row] = value / a[row][row];
      if (!result[row].isFinite) return null;
    }
    return result;
  }
}
