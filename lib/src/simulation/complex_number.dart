import 'dart:math' as math;

/// Minimal immutable complex number used by the frequency-domain MNA solver.
class ComplexNumber {
  const ComplexNumber(this.real, [this.imaginary = 0]);

  final double real;
  final double imaginary;

  static const zero = ComplexNumber(0);
  static const one = ComplexNumber(1);

  factory ComplexNumber.polar(double magnitude, double angle) =>
      ComplexNumber(
        magnitude * math.cos(angle),
        magnitude * math.sin(angle),
      );

  ComplexNumber operator +(ComplexNumber other) => ComplexNumber(
        real + other.real,
        imaginary + other.imaginary,
      );

  ComplexNumber operator -(ComplexNumber other) => ComplexNumber(
        real - other.real,
        imaginary - other.imaginary,
      );

  ComplexNumber operator *(ComplexNumber other) => ComplexNumber(
        real * other.real - imaginary * other.imaginary,
        real * other.imaginary + imaginary * other.real,
      );

  ComplexNumber operator /(ComplexNumber other) {
    final denominator = other.real * other.real +
        other.imaginary * other.imaginary;
    if (denominator == 0) throw StateError('Complex division by zero.');
    return ComplexNumber(
      (real * other.real + imaginary * other.imaginary) / denominator,
      (imaginary * other.real - real * other.imaginary) / denominator,
    );
  }

  ComplexNumber operator -() => ComplexNumber(-real, -imaginary);

  double get magnitude => math.sqrt(
        real * real + imaginary * imaginary,
      );

  double get angle => math.atan2(imaginary, real);

  bool get isFinite => real.isFinite && imaginary.isFinite;

  @override
  String toString() => 'ComplexNumber($real, $imaginary)';
}
