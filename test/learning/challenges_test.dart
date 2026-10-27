import 'package:elec_lab/src/learning/challenges.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  test('self-holding challenge requires released Start and calculated coil state', () {
    var project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'challenge', name: 'Challenge', now: testNow),
      ProjectTemplateKind.selfHolding,
    );
    final challenge = LocalChallenges.all.singleWhere((item) => item.id == 'self_holding');
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(challenge.evaluateProject(project, result).achieved, isFalse);

    project = setProperty(project, 's1', 'pressed', true);
    result = simulator.step(project);
    expect(challenge.evaluateProject(project, result).achieved, isFalse);

    project = setProperty(project, 's1', 'pressed', false);
    result = simulator.step(project);
    final progress = challenge.evaluateProject(project, result);
    expect(progress.criteria, <bool>[true, true, true]);
    expect(progress.achieved, isTrue);
  });
}
