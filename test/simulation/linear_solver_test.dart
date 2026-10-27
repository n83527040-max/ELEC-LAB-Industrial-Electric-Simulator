import 'package:elec_lab/src/simulation/complex_number.dart';
import 'package:elec_lab/src/simulation/linear_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complex arithmetic follows polar and division rules', () {
    final value = ComplexNumber.polar(2, 0);
    expect(value.real, closeTo(2, 1e-12));
    expect(value.imaginary, closeTo(0, 1e-12));
    final quotient = const ComplexNumber(4, 2) / const ComplexNumber(2, 1);
    expect(quotient.real, closeTo(2, 1e-12));
    expect(quotient.imaginary, closeTo(0, 1e-12));
  });

  test('MNA solver resolves a complex diagonal system', () {
    final result = LinearSolver.solve(
      <List<ComplexNumber>>[
        <ComplexNumber>[const ComplexNumber(0, 1), ComplexNumber.zero],
        <ComplexNumber>[ComplexNumber.zero, const ComplexNumber(2, 1)],
      ],
      <ComplexNumber>[const ComplexNumber(2), const ComplexNumber(4, 2)],
    );
    expect(result, isNotNull);
    expect(result![0].real, closeTo(0, 1e-10));
    expect(result[0].imaginary, closeTo(-2, 1e-10));
    expect(result[1].real, closeTo(2, 1e-10));
    expect(result[1].imaginary, closeTo(0, 1e-10));
  });

  test('singular systems return null rather than NaN measurements', () {
    final result = LinearSolver.solve(
      <List<ComplexNumber>>[
        <ComplexNumber>[ComplexNumber.one, ComplexNumber.one],
        <ComplexNumber>[const ComplexNumber(2), const ComplexNumber(2)],
      ],
      <ComplexNumber>[ComplexNumber.one, const ComplexNumber(2)],
    );
    expect(result, isNull);
  });
}
