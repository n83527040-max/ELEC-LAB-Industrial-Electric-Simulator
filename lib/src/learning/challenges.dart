import '../models/project.dart';
import '../models/terminal.dart';
import '../simulation/simulation_result.dart';

enum ChallengeLevel { beginner, intermediate, advanced, professional }

class ChallengeProgress {
  const ChallengeProgress({required this.criteria, required this.hints});

  final List<bool> criteria;
  final List<String> hints;

  bool get achieved => criteria.every((item) => item);
  double get fraction => criteria.isEmpty
      ? 0
      : criteria.where((item) => item).length / criteria.length;
}

class LearningChallenge {
  const LearningChallenge({
    required this.id,
    required this.title,
    required this.level,
    required this.objective,
    required this.criteriaLabels,
    required this.hints,
    required this.evaluate,
  });

  final String id;
  final String title;
  final ChallengeLevel level;
  final String objective;
  final List<String> criteriaLabels;
  final List<String> hints;
  final List<bool> Function(ElectricalProject project, SimulationResult? result)
      evaluate;

  ChallengeProgress evaluateProject(
    ElectricalProject project,
    SimulationResult? result,
  ) =>
      ChallengeProgress(criteria: evaluate(project, result), hints: hints);
}

abstract final class LocalChallenges {
  static final List<LearningChallenge> all = <LearningChallenge>[
    LearningChallenge(
      id: 'dc_lamp',
      title: 'تشغيل وإيقاف مصباح',
      level: ChallengeLevel.beginner,
      objective: 'أنشئ مساراً DC وشغّل Voyant بالضغط على Bouton NO.',
      criteriaLabels: const <String>['مصدر وزر ومصباح', 'ثلاثة أسلاك على الأقل', 'المصباح يضيء بالحساب'],
      hints: const <String>[
        'ابدأ من قالب «تشغيل مصباح DC» إذا أردت مثالاً.',
        'صل +24V بدخل الزر، وخرج الزر بـX1، ثم X2 بـ0V.',
        'شغّل المحاكاة واستمر بالضغط على الزر الأخضر.',
      ],
      evaluate: (project, result) => <bool>[
        _has(project, ComponentKind.dcSupply) &&
            _has(project, ComponentKind.pushButtonNO) &&
            _has(project, ComponentKind.indicator),
        project.wires.length >= 3,
        _active(project, result, ComponentKind.indicator),
      ],
    ),
    LearningChallenge(
      id: 'self_holding',
      title: 'التعشيق الذاتي',
      level: ChallengeLevel.intermediate,
      objective: 'أبقِ Contacteur منشطاً بعد تحرير زر التشغيل باستعمال 13/14.',
      criteriaLabels: const <String>['كونتاكتور وزرا Start/Stop', 'استعمال 13NO و14NO', 'الملف باقٍ منشطاً بعد تحرير Start'],
      hints: const <String>[
        'نقطة 13/14 توضع على التوازي مع Bouton Start.',
        'ضع Bouton Stop NC قبل تفرع Start والتعشيق.',
        'اضغط Start ثم حرره؛ لا يكفي بقاء الزر مضغوطاً لنجاح التحدي.',
      ],
      evaluate: (project, result) {
        final contactors = project.components.where(
          (item) => item.kind == ComponentKind.contactor,
        );
        final usesAux = project.wires.any(
          (wire) =>
              (wire.from.terminalId == 'aux13' || wire.from.terminalId == 'aux14') &&
              contactors.any((item) => item.id == wire.from.componentId),
        );
        final startReleased = project.components
            .where((item) => item.kind == ComponentKind.pushButtonNO)
            .every((item) => !item.flag('pressed'));
        return <bool>[
          contactors.isNotEmpty &&
              _has(project, ComponentKind.pushButtonNO) &&
              _has(project, ComponentKind.pushButtonNC),
          usesAux,
          startReleased &&
              contactors.any((item) => result?[item.id]?.energized ?? false),
        ];
      },
    ),
    LearningChallenge(
      id: 'timer',
      title: 'التشغيل بعد زمن',
      level: ChallengeLevel.advanced,
      objective: 'غذِّ Temporisateur وتحقق من إغلاق 15/18 بعد الزمن المحدد.',
      criteriaLabels: const <String>['مؤقت مع سلك للملف', 'الملف منشط', 'انتهت مهلة ON-delay'],
      hints: const <String>[
        'الملف بين A1 وA2، ونقطة الخرج بين 15 و18.',
        'غيّر delaySeconds من خصائص المؤقت.',
        'الزمن يتقدم من نتائج المحرك، وليس من حركة الواجهة.',
      ],
      evaluate: (project, result) {
        final timers = project.components
            .where((item) => item.kind == ComponentKind.timer)
            .toList();
        return <bool>[
          timers.isNotEmpty &&
              project.wires.any((wire) => wire.touches(
                    TerminalRef(componentId: timers.first.id, terminalId: 'a1'),
                  )),
          timers.any((item) => result?[item.id]?.energized ?? false),
          timers.any((item) => result?[item.id]?.active ?? false),
        ];
      },
    ),
    LearningChallenge(
      id: 'motor_protection',
      title: 'حماية محرك',
      level: ChallengeLevel.advanced,
      objective: 'شغّل Moteur triphasé عبر Contacteur وRelais thermique.',
      criteriaLabels: const <String>['الأجهزة المطلوبة موجودة', 'مسارات الأطوار الثلاثة', 'المحرك يعمل والحماية غير مفصولة'],
      hints: const <String>[
        'استعمل قالب «حماية محرك ثلاثي الطور».',
        'صل L1/L2/L3 بالتتابع دون تبديل، وPE بـPE.',
        'اجعل 95/96 على التسلسل مع ملف الكونتاكتور.',
      ],
      evaluate: (project, result) {
        final motor = project.components
            .where((item) => item.kind == ComponentKind.motor3Phase)
            .firstOrNull;
        final thermal = project.components
            .where((item) => item.kind == ComponentKind.thermalRelay)
            .firstOrNull;
        return <bool>[
          motor != null &&
              thermal != null &&
              _has(project, ComponentKind.contactor) &&
              _has(project, ComponentKind.threePhaseSupply),
          project.wires.length >= 12,
          motor != null &&
              (result?[motor.id]?.active ?? false) &&
              thermal != null &&
              !(result?[thermal.id]?.tripped ?? false),
        ];
      },
    ),
    LearningChallenge(
      id: 'reverse',
      title: 'عكس اتجاه الدوران',
      level: ChallengeLevel.professional,
      objective: 'بدّل طورين فقط لتحصل على اتجاه عكسي محسوب من تسلسل الأطوار.',
      criteriaLabels: const <String>['محرك ثلاثي الطور', 'المحرك يعمل', 'تسلسل الأطوار عكسي'],
      hints: const <String>[
        'أوقف المحاكاة قبل تعديل التوصيلات الافتراضية.',
        'بدّل سلكي طورين عند U/V/W، ولا تبدل الأطوار الثلاثة.',
        'النتيجة تعتمد زوايا phasors، وليست زر اتجاه شكلياً.',
      ],
      evaluate: (project, result) {
        final motors = project.components.where(
          (item) => item.kind == ComponentKind.motor3Phase,
        );
        return <bool>[
          motors.isNotEmpty,
          motors.any((item) => result?[item.id]?.active ?? false),
          motors.any((item) => (result?[item.id]?.direction ?? 0) < 0),
        ];
      },
    ),
  ];

  static String levelName(ChallengeLevel level) => switch (level) {
        ChallengeLevel.beginner => 'مبتدئ',
        ChallengeLevel.intermediate => 'متوسط',
        ChallengeLevel.advanced => 'متقدم',
        ChallengeLevel.professional => 'احترافي',
      };

  static bool _has(ElectricalProject project, ComponentKind kind) =>
      project.components.any((item) => item.kind == kind);

  static bool _active(
    ElectricalProject project,
    SimulationResult? result,
    ComponentKind kind,
  ) =>
      project.components.any(
        (item) => item.kind == kind && (result?[item.id]?.active ?? false),
      );
}

abstract final class DiagnosticAdvisor {
  static List<String> hintsFor(SimulationDiagnostic diagnostic) {
    return switch (diagnostic.code) {
      'no_supply' => const <String>[
          'افتح زر «مصادر التغذية» أسفل المحرر.',
          'اختر DC 24V لدوائر التحكم البسيطة.',
        ],
      'supply_disabled' => const <String>[
          'فعّل المصدر المطلوب فقط من Supply Bay أو من زر ON/OFF عليه.',
          'اضبط الجهد والتردد من الخصائص قبل توصيل الأحمال.',
        ],
      'singular_network' => const <String>[
          'ابحث عن سلك يصل مباشرة بين خرجي مصدرين.',
          'افصل أحد المصدرين أو صل الأحمال بدل تعارض المصادر.',
        ],
      'invalid_measurement' => const <String>[
          'Voltmètre على التوازي، وAmpèremètre على التسلسل.',
          'تحقق أيضاً من مدى الجهد أو التيار في الخصائص.',
        ],
      'motor_phase_problem' => const <String>[
          'قِس الجهد بين U/V/W للتأكد من وصول الأطوار الثلاثة.',
          'تحقق من Contacteur وRelais thermique والأسلاك المفتوحة.',
        ],
      'differential_trip' => const <String>[
          'تحقق من تيار التسرب ومن عودة N عبر القاطع التفاضلي.',
          'PE مسار حماية ولا يدخل كتيار حمل داخل قياس ΔI.',
        ],
      'breaker_trip' ||
      'thermal_trip' ||
      'motor_breaker_trip' ||
      'fuse_blown' => const <String>[
          'افحص القصر أو الحمل الزائد قبل إعادة الضبط.',
          'قارن التيار المحسوب بالتيار المقنن للحماية.',
          'لا ترفع تصنيف الحماية لمجرد إخفاء العطل.',
        ],
      _ => const <String>[
          'تتبع المسار من المصدر إلى الحمل ثم إلى العودة.',
          'استخدم نقاط القياس ورسائل التشخيص لتحديد أول انقطاع.',
        ],
    };
  }
}
