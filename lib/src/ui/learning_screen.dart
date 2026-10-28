import 'package:flutter/material.dart';

import '../learning/challenges.dart';
import '../models/project.dart';
import '../simulation/simulation_result.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key, this.project, this.result});

  final ElectricalProject? project;
  final SimulationResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التعلم والتحديات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.offline_bolt, size: 38, color: Color(0xff00a6ff)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تحديات ومساعدة محلية تعمل دون إنترنت. النجاح يقاس من نموذج الدائرة ونتائج المحاكاة، لا من صورة نهائية.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (project == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('افتح التحديات من داخل مشروع لعرض تقدمك الفعلي.'),
            ),
          ...LocalChallenges.all.map(
            (challenge) => _ChallengeCard(
              challenge: challenge,
              project: project,
              result: result,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.project,
    required this.result,
  });

  final LearningChallenge challenge;
  final ElectricalProject? project;
  final SimulationResult? result;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  int _visibleHints = 0;

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final progress = widget.project == null
        ? null
        : challenge.evaluateProject(widget.project!, widget.result);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: progress?.achieved == true
              ? const Icon(Icons.check)
              : const Icon(Icons.school),
        ),
        title: Text(challenge.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(LocalChallenges.levelName(challenge.level)),
            if (progress != null) ...<Widget>[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress.fraction),
            ],
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(challenge.objective),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < challenge.criteriaLabels.length; index++)
            Row(
              children: <Widget>[
                Icon(
                  progress?.criteria[index] == true
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: progress?.criteria[index] == true
                      ? Colors.green
                      : Colors.blueGrey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(challenge.criteriaLabels[index])),
              ],
            ),
          const Divider(),
          for (var index = 0; index < _visibleHints; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.lightbulb_outline,
                      size: 20, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(challenge.hints[index])),
                ],
              ),
            ),
          if (_visibleHints < challenge.hints.length)
            TextButton.icon(
              onPressed: () => setState(() => _visibleHints++),
              icon: const Icon(Icons.tips_and_updates),
              label: Text(_visibleHints == 0 ? 'أعطني تلميحاً' : 'تلميح إضافي'),
            ),
        ],
      ),
    );
  }
}
