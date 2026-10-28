import 'dart:ui' show Size;

import 'component.dart';
import 'component_catalog_extensions.dart';
import 'geometry.dart';
import 'terminal.dart';

/// Single source of truth for board terminals, simulation terminals and 3D
/// terminal labels. Only components with an implemented electrical model are
/// listed here.
abstract final class ComponentCatalog {
  static final Map<ComponentKind, ComponentSpec> byKind =
      <ComponentKind, ComponentSpec>{
    ComponentKind.dcSupply: ComponentSpec(
      kind: ComponentKind.dcSupply,
      nameAr: 'مصدر تغذية DC',
      nameFr: 'Alimentation DC',
      category: ComponentCategory.sources,
      size: const Size(112, 126),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'positive',
          label: '+',
          position: BoardPoint(32, 126),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'negative',
          label: '0V',
          position: BoardPoint(80, 126),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'voltage': 24.0,
        'internalResistance': 0.05,
        'enabled': false,
      },
      description: 'مصدر جهد مستمر مع مقاومة داخلية صغيرة قابلة للضبط.',
    ),
    ComponentKind.acSupply: ComponentSpec(
      kind: ComponentKind.acSupply,
      nameAr: 'مصدر أحادي الطور',
      nameFr: 'Alimentation monophasée',
      category: ComponentCategory.sources,
      size: const Size(112, 126),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'line',
          label: 'L',
          position: BoardPoint(32, 126),
          kind: TerminalKind.power,
          phase: 'L',
        ),
        TerminalDefinition(
          id: 'neutral',
          label: 'N',
          position: BoardPoint(80, 126),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'voltage': 24.0,
        'frequency': 50.0,
        'internalResistance': 0.05,
        'enabled': false,
      },
      description: 'مصدر جهد جيبي RMS؛ غيّر الجهد إلى 230V عند الحاجة.',
    ),
    ComponentKind.threePhaseSupply: ComponentSpec(
      kind: ComponentKind.threePhaseSupply,
      nameAr: 'مصدر ثلاثي الطور',
      nameFr: 'Alimentation triphasée',
      category: ComponentCategory.sources,
      size: const Size(142, 126),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'l1',
          label: 'L1',
          position: BoardPoint(24, 126),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 'l2',
          label: 'L2',
          position: BoardPoint(56, 126),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 'l3',
          label: 'L3',
          position: BoardPoint(88, 126),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 'neutral',
          label: 'N',
          position: BoardPoint(120, 126),
          kind: TerminalKind.neutral,
        ),
        TerminalDefinition(
          id: 'pe',
          label: 'PE',
          position: BoardPoint(142, 88),
          kind: TerminalKind.earth,
        ),
      ],
      defaultProperties: const <String, Object>{
        'lineVoltage': 400.0,
        'frequency': 50.0,
        'internalResistance': 0.05,
        'enabled': false,
      },
      description: 'ثلاثة مصادر متوازنة؛ 400V بين الأطوار و230V للمحايد.',
    ),
    ComponentKind.circuitBreaker: ComponentSpec(
      kind: ComponentKind.circuitBreaker,
      nameAr: 'قاطع كهربائي',
      nameFr: 'Disjoncteur MCB',
      category: ComponentCategory.protection,
      size: const Size(78, 136),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'line',
          label: '1/L',
          position: BoardPoint(39, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'load',
          label: '2/T',
          position: BoardPoint(39, 136),
          kind: TerminalKind.power,
        ),
      ],
      defaultProperties: const <String, Object>{
        'ratedCurrent': 10.0,
        'closed': true,
        'fault': 'none',
      },
      description: 'قاطع أحادي القطب مع فصل مغناطيسي وحراري مبسط.',
    ),
    ComponentKind.differentialBreaker: ComponentSpec(
      kind: ComponentKind.differentialBreaker,
      nameAr: 'قاطع تفاضلي',
      nameFr: 'Disjoncteur différentiel',
      category: ComponentCategory.protection,
      size: const Size(112, 156),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'lineIn',
          label: 'L IN',
          position: BoardPoint(32, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'neutralIn',
          label: 'N IN',
          position: BoardPoint(80, 0),
          kind: TerminalKind.neutral,
        ),
        TerminalDefinition(
          id: 'lineOut',
          label: 'L OUT',
          position: BoardPoint(32, 156),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'neutralOut',
          label: 'N OUT',
          position: BoardPoint(80, 156),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'ratedCurrent': 25.0,
        'residualThreshold': 0.03,
        'closed': true,
        'fault': 'none',
      },
      description:
          'نموذج تعليمي ثنائي القطب يحسب مجموع تياري L وN ويفصل عند تجاوز عتبة التسرب أو الحمل.',
    ),
    ComponentKind.motorBreaker: ComponentSpec(
      kind: ComponentKind.motorBreaker,
      nameAr: 'قاطع حماية المحرك',
      nameFr: 'Disjoncteur moteur',
      category: ComponentCategory.protection,
      size: const Size(142, 158),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'l1',
          label: '1/L1',
          position: BoardPoint(24, 0),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 'l2',
          label: '3/L2',
          position: BoardPoint(55, 0),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 'l3',
          label: '5/L3',
          position: BoardPoint(86, 0),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 't1',
          label: '2/T1',
          position: BoardPoint(24, 158),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 't2',
          label: '4/T2',
          position: BoardPoint(55, 158),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 't3',
          label: '6/T3',
          position: BoardPoint(86, 158),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 'nc95',
          label: '95NC',
          position: BoardPoint(0, 126),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'nc96',
          label: '96NC',
          position: BoardPoint(142, 126),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'ratedCurrent': 4.0,
        'tripTime': 5.0,
        'closed': true,
        'fault': 'none',
      },
      description:
          'حماية ثلاثية الأطوار بتجميع حراري مبسط وفصل مغناطيسي ونقطة NC للتحكم.',
    ),
    ComponentKind.contactor: ComponentSpec(
      kind: ComponentKind.contactor,
      nameAr: 'كونتاكتور',
      nameFr: 'Contacteur 3P + aux',
      category: ComponentCategory.contactors,
      size: const Size(142, 158),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'l1',
          label: '1/L1',
          position: BoardPoint(24, 0),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 'l2',
          label: '3/L2',
          position: BoardPoint(55, 0),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 'l3',
          label: '5/L3',
          position: BoardPoint(86, 0),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 't1',
          label: '2/T1',
          position: BoardPoint(24, 158),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 't2',
          label: '4/T2',
          position: BoardPoint(55, 158),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 't3',
          label: '6/T3',
          position: BoardPoint(86, 158),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 'a1',
          label: 'A1',
          position: BoardPoint(142, 42),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 'a2',
          label: 'A2',
          position: BoardPoint(142, 118),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 'aux13',
          label: '13NO',
          position: BoardPoint(0, 48),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'aux14',
          label: '14NO',
          position: BoardPoint(0, 80),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'aux21',
          label: '21NC',
          position: BoardPoint(0, 108),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'aux22',
          label: '22NC',
          position: BoardPoint(0, 136),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'coilVoltage': 24.0,
        'coilResistance': 300.0,
        'pickupRatio': 0.8,
        'dropoutRatio': 0.35,
        'interlockGroup': '',
        'interlockRole': '',
        'fault': 'none',
      },
      description: 'ثلاث نقاط قدرة NO وملف ونقطة NO ونقطة NC مساعدتان.',
    ),
    ComponentKind.thermalRelay: ComponentSpec(
      kind: ComponentKind.thermalRelay,
      nameAr: 'مرحل حراري',
      nameFr: 'Relais thermique',
      category: ComponentCategory.protection,
      size: const Size(112, 128),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'l1',
          label: '1/L1',
          position: BoardPoint(24, 0),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 'l2',
          label: '3/L2',
          position: BoardPoint(52, 0),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 'l3',
          label: '5/L3',
          position: BoardPoint(80, 0),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 't1',
          label: '2/T1',
          position: BoardPoint(24, 128),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 't2',
          label: '4/T2',
          position: BoardPoint(52, 128),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 't3',
          label: '6/T3',
          position: BoardPoint(80, 128),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 'nc95',
          label: '95NC',
          position: BoardPoint(0, 82),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'nc96',
          label: '96NC',
          position: BoardPoint(112, 82),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'ratedCurrent': 4.0,
        'tripTime': 5.0,
        'fault': 'none',
      },
      description:
          'ثلاثة مسارات قدرة L1/T1 وL2/T2 وL3/T3 ونقطة NC تفتح عند الحمل الزائد.',
    ),
    ComponentKind.auxiliaryRelay: ComponentSpec(
      kind: ComponentKind.auxiliaryRelay,
      nameAr: 'ريلي مساعد',
      nameFr: 'Relais auxiliaire',
      category: ComponentCategory.contactors,
      size: const Size(104, 130),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'a1',
          label: 'A1',
          position: BoardPoint(104, 28),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 'a2',
          label: 'A2',
          position: BoardPoint(104, 102),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 'common',
          label: '11',
          position: BoardPoint(0, 28),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'no',
          label: '14NO',
          position: BoardPoint(0, 65),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'nc',
          label: '12NC',
          position: BoardPoint(0, 102),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'coilVoltage': 24.0,
        'coilResistance': 300.0,
        'pickupRatio': 0.8,
        'dropoutRatio': 0.35,
        'fault': 'none',
      },
      description: 'ملف ونقطة تبديل SPDT مع common وNO وNC.',
    ),
    ComponentKind.pushButtonNO: _buttonSpec(
      kind: ComponentKind.pushButtonNO,
      nameAr: 'زر تشغيل NO',
      nameFr: 'Bouton poussoir NO',
      colorName: 'green',
    ),
    ComponentKind.pushButtonNC: _buttonSpec(
      kind: ComponentKind.pushButtonNC,
      nameAr: 'زر إيقاف NC',
      nameFr: 'Bouton poussoir NC',
      colorName: 'red',
    ),
    ComponentKind.emergencyStop: ComponentSpec(
      kind: ComponentKind.emergencyStop,
      nameAr: 'زر توقف اضطراري',
      nameFr: 'Arrêt d\'urgence',
      category: ComponentCategory.control,
      size: const Size(96, 108),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'input',
          label: '21',
          position: BoardPoint(48, 0),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'output',
          label: '22',
          position: BoardPoint(48, 108),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'closed': true,
        'fault': 'none',
      },
      description:
          'نقطة NC مع maintained stop؛ اضغط أثناء المحاكاة للفصل وإعادة التعشيق.',
    ),
    ComponentKind.selectorSwitch: ComponentSpec(
      kind: ComponentKind.selectorSwitch,
      nameAr: 'مفتاح اختيار',
      nameFr: 'Sélecteur',
      category: ComponentCategory.control,
      size: const Size(82, 92),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'input',
          label: '1',
          position: BoardPoint(41, 0),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'output',
          label: '2',
          position: BoardPoint(41, 92),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'closed': false,
        'fault': 'none',
      },
      description: 'مفتاح يحتفظ بوضعه؛ اضغط عليه أثناء المحاكاة لتغييره.',
    ),
    ComponentKind.rotarySwitch: ComponentSpec(
      kind: ComponentKind.rotarySwitch,
      nameAr: 'مفتاح دوار 0-1-2',
      nameFr: 'Commutateur rotatif',
      category: ComponentCategory.control,
      size: const Size(96, 104),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'common',
          label: 'COM',
          position: BoardPoint(48, 0),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'out1',
          label: '1',
          position: BoardPoint(24, 104),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'out2',
          label: '2',
          position: BoardPoint(72, 104),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'position': 0,
        'fault': 'none',
      },
      description:
          'مفتاح maintained بثلاث وضعيات؛ يصل COM إلى 1 أو 2 حسب الاختيار.',
    ),
    ComponentKind.timer: ComponentSpec(
      kind: ComponentKind.timer,
      nameAr: 'مؤقت عند التشغيل',
      nameFr: 'Temporisateur ON-delay',
      category: ComponentCategory.timers,
      size: const Size(106, 138),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'a1',
          label: 'A1',
          position: BoardPoint(106, 32),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 'a2',
          label: 'A2',
          position: BoardPoint(106, 106),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 't15',
          label: '15',
          position: BoardPoint(0, 42),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 't16',
          label: '16NC',
          position: BoardPoint(0, 70),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 't18',
          label: '18NO',
          position: BoardPoint(0, 102),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'coilVoltage': 24.0,
        'coilResistance': 300.0,
        'delaySeconds': 3.0,
        'fault': 'none',
      },
      description: 'نقطة تبديل: 15/16 مغلقة قبل التأخير و15/18 تغلق بعده.',
    ),
    ComponentKind.timerOffDelay: ComponentSpec(
      kind: ComponentKind.timerOffDelay,
      nameAr: 'مؤقت عند الفصل',
      nameFr: 'Temporisateur OFF-delay',
      category: ComponentCategory.timers,
      size: const Size(106, 138),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'a1',
          label: 'A1',
          position: BoardPoint(106, 32),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 'a2',
          label: 'A2',
          position: BoardPoint(106, 106),
          kind: TerminalKind.coil,
        ),
        TerminalDefinition(
          id: 't15',
          label: '15',
          position: BoardPoint(0, 42),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 't16',
          label: '16NC',
          position: BoardPoint(0, 70),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 't18',
          label: '18NO',
          position: BoardPoint(0, 102),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'coilVoltage': 24.0,
        'coilResistance': 300.0,
        'delaySeconds': 3.0,
        'fault': 'none',
      },
      description:
          'نقطة تبديل: تغلق 15/18 مع الملف وتبقى لمدة التأخير بعد فصله، بينما 15/16 عكسها.',
    ),
    ComponentKind.sensor: ComponentSpec(
      kind: ComponentKind.sensor,
      nameAr: 'حساس NO',
      nameFr: 'Capteur NO',
      category: ComponentCategory.sensors,
      size: const Size(84, 94),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'input',
          label: 'BN',
          position: BoardPoint(42, 0),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'output',
          label: 'BK',
          position: BoardPoint(42, 94),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'active': false,
        'fault': 'none',
      },
      description: 'حساس تعليمي NO يمكن تنشيطه يدوياً أثناء المحاكاة.',
    ),
    ComponentKind.limitSwitch: ComponentSpec(
      kind: ComponentKind.limitSwitch,
      nameAr: 'مفتاح نهاية مشوار',
      nameFr: 'Fin de course',
      category: ComponentCategory.sensors,
      size: const Size(86, 112),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'input',
          label: '3',
          position: BoardPoint(43, 0),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'output',
          label: '4',
          position: BoardPoint(43, 112),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'active': false,
        'fault': 'none',
      },
      description:
          'نقطة NO بمحرك roller؛ التنشيط اليدوي يمثل وصول الجزء الميكانيكي.',
    ),
    ComponentKind.indicator: ComponentSpec(
      kind: ComponentKind.indicator,
      nameAr: 'مصباح إشارة',
      nameFr: 'Voyant',
      category: ComponentCategory.signals,
      size: const Size(76, 100),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'x1',
          label: 'X1',
          position: BoardPoint(38, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'x2',
          label: 'X2',
          position: BoardPoint(38, 100),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'ratedVoltage': 24.0,
        'powerWatts': 2.0,
        'color': 'red',
        'fault': 'none',
      },
      description: 'حمل مقاوم؛ الإضاءة والقدرة محسوبتان من الجهد الفعلي.',
    ),
    ComponentKind.motor3Phase: ComponentSpec(
      kind: ComponentKind.motor3Phase,
      nameAr: 'محرك ثلاثي الطور',
      nameFr: 'Moteur triphasé',
      category: ComponentCategory.motors,
      size: const Size(170, 136),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'u',
          label: 'U1',
          position: BoardPoint(40, 0),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 'v',
          label: 'V1',
          position: BoardPoint(85, 0),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 'w',
          label: 'W1',
          position: BoardPoint(130, 0),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 'earth',
          label: 'PE',
          position: BoardPoint(160, 100),
          kind: TerminalKind.earth,
        ),
      ],
      defaultProperties: const <String, Object>{
        'nominalVoltage': 400.0,
        'nominalCurrent': 2.0,
        'powerFactor': 0.8,
        'fault': 'none',
      },
      description: 'معاوقة واي متوازنة؛ يحدد الدوران وتسلسل الأطوار من الحل.',
    ),
    ComponentKind.motor1Phase: ComponentSpec(
      kind: ComponentKind.motor1Phase,
      nameAr: 'محرك أحادي الطور',
      nameFr: 'Moteur monophasé',
      category: ComponentCategory.motors,
      size: const Size(150, 128),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'u',
          label: 'U1',
          position: BoardPoint(40, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'v',
          label: 'U2',
          position: BoardPoint(100, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'earth',
          label: 'PE',
          position: BoardPoint(140, 96),
          kind: TerminalKind.earth,
        ),
      ],
      defaultProperties: const <String, Object>{
        'nominalVoltage': 230.0,
        'nominalCurrent': 2.0,
        'powerFactor': 0.8,
        'fault': 'none',
      },
      description:
          'معاوقة steady-state أحادية الطور؛ لا يحسب عزم الإقلاع أو مكثف البدء.',
    ),
    ComponentKind.transformer: ComponentSpec(
      kind: ComponentKind.transformer,
      nameAr: 'محول كهربائي',
      nameFr: 'Transformateur',
      category: ComponentCategory.sources,
      size: const Size(150, 146),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'primaryLine',
          label: 'L PRI',
          position: BoardPoint(24, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'primaryNeutral',
          label: 'N PRI',
          position: BoardPoint(64, 0),
          kind: TerminalKind.neutral,
        ),
        TerminalDefinition(
          id: 'secondaryLine',
          label: 'L SEC',
          position: BoardPoint(86, 146),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'secondaryNeutral',
          label: 'N SEC',
          position: BoardPoint(126, 146),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'primaryVoltage': 230.0,
        'secondaryVoltage': 24.0,
        'primaryResistance': 0.2,
        'secondaryResistance': 0.1,
        'fault': 'none',
      },
      description:
          'محول مثالي مقترن داخل MNA مع مقاومتي الملفات؛ النسبة من جهدي Primary/Secondary.',
    ),
    ComponentKind.terminalBlock: ComponentSpec(
      kind: ComponentKind.terminalBlock,
      nameAr: 'كتلة توصيل',
      nameFr: 'Bornier',
      category: ComponentCategory.terminals,
      size: const Size(62, 86),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'a',
          label: 'A',
          position: BoardPoint(31, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'b',
          label: 'B',
          position: BoardPoint(31, 86),
          kind: TerminalKind.power,
        ),
      ],
      defaultProperties: const <String, Object>{'fault': 'none'},
      description: 'وصلة كهربائية بين Bornes A وB.',
    ),
    ComponentKind.voltmeter: ComponentSpec(
      kind: ComponentKind.voltmeter,
      nameAr: 'فولتمتر',
      nameFr: 'Voltmètre',
      category: ComponentCategory.measurement,
      size: const Size(94, 94),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'positive',
          label: 'V+',
          position: BoardPoint(47, 0),
          kind: TerminalKind.measurement,
        ),
        TerminalDefinition(
          id: 'negative',
          label: 'V−',
          position: BoardPoint(47, 94),
          kind: TerminalKind.measurement,
        ),
      ],
      defaultProperties: const <String, Object>{'maxVoltage': 600.0},
      description: 'مقاومة داخلية 1MΩ ويقيس مقدار الجهد RMS أو DC.',
    ),
    ComponentKind.ammeter: ComponentSpec(
      kind: ComponentKind.ammeter,
      nameAr: 'أمبيرمتر',
      nameFr: 'Ampèremètre',
      category: ComponentCategory.measurement,
      size: const Size(94, 94),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'positive',
          label: 'A+',
          position: BoardPoint(47, 0),
          kind: TerminalKind.measurement,
        ),
        TerminalDefinition(
          id: 'negative',
          label: 'A−',
          position: BoardPoint(47, 94),
          kind: TerminalKind.measurement,
        ),
      ],
      defaultProperties: const <String, Object>{'maxCurrent': 10.0},
      description: 'مقاومة داخلية 10mΩ ويجب توصيله على التسلسل.',
    ),
    ComponentKind.digitalCounter: ComponentSpec(
      kind: ComponentKind.digitalCounter,
      nameAr: 'عداد طاقة رقمي',
      nameFr: 'Compteur numérique',
      category: ComponentCategory.measurement,
      size: const Size(108, 104),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'voltageL',
          label: 'V L',
          position: BoardPoint(30, 0),
          kind: TerminalKind.measurement,
        ),
        TerminalDefinition(
          id: 'voltageN',
          label: 'V N',
          position: BoardPoint(78, 0),
          kind: TerminalKind.measurement,
        ),
        TerminalDefinition(
          id: 'currentIn',
          label: 'I IN',
          position: BoardPoint(30, 104),
          kind: TerminalKind.measurement,
        ),
        TerminalDefinition(
          id: 'currentOut',
          label: 'I OUT',
          position: BoardPoint(78, 104),
          kind: TerminalKind.measurement,
        ),
      ],
      defaultProperties: const <String, Object>{
        'maxVoltage': 600.0,
        'maxCurrent': 20.0,
      },
      description:
          'قياس رباعي الأطراف: جهد على التوازي وتيار على التسلسل، مع تكامل الطاقة kWh من الزمن والقدرة.',
    ),
    ComponentKind.fuse: ComponentSpec(
      kind: ComponentKind.fuse,
      nameAr: 'فيوز',
      nameFr: 'Fusible',
      category: ComponentCategory.protection,
      size: const Size(72, 100),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'line',
          label: 'IN',
          position: BoardPoint(36, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'load',
          label: 'OUT',
          position: BoardPoint(36, 100),
          kind: TerminalKind.power,
        ),
      ],
      defaultProperties: const <String, Object>{
        'ratedCurrent': 6.0,
        'fault': 'none',
      },
      description: 'ينصهر عند تجاوز مستمر للتيار ويحتاج استبدالاً افتراضياً.',
    ),
    ...ExtendedComponentCatalog.byKind,
  };

  static ComponentSpec specOf(ComponentKind kind) => byKind[kind]!;

  static List<ComponentSpec> search(String query, ComponentCategory? category) {
    final normalized = query.trim().toLowerCase();
    return byKind.values.where((spec) {
      final categoryMatches = category == null || spec.category == category;
      final queryMatches = normalized.isEmpty ||
          spec.nameAr.toLowerCase().contains(normalized) ||
          spec.nameFr.toLowerCase().contains(normalized) ||
          spec.kind.name.toLowerCase().contains(normalized);
      return categoryMatches && queryMatches;
    }).toList(growable: false);
  }

  static String categoryName(ComponentCategory category) => switch (category) {
        ComponentCategory.sources => 'مصادر التغذية',
        ComponentCategory.protection => 'الحمايات',
        ComponentCategory.contactors => 'كونتاكتورات وريليات',
        ComponentCategory.control => 'أزرار التحكم',
        ComponentCategory.timers => 'مؤقتات',
        ComponentCategory.sensors => 'حساسات',
        ComponentCategory.motors => 'المحركات',
        ComponentCategory.signals => 'الإشارات',
        ComponentCategory.measurement => 'القياس',
        ComponentCategory.terminals => 'البورنات',
      };

  static ComponentSpec _buttonSpec({
    required ComponentKind kind,
    required String nameAr,
    required String nameFr,
    required String colorName,
  }) {
    return ComponentSpec(
      kind: kind,
      nameAr: nameAr,
      nameFr: nameFr,
      category: ComponentCategory.control,
      size: const Size(82, 92),
      terminals: const <TerminalDefinition>[
        TerminalDefinition(
          id: 'input',
          label: '3',
          position: BoardPoint(41, 0),
          kind: TerminalKind.auxiliary,
        ),
        TerminalDefinition(
          id: 'output',
          label: '4',
          position: BoardPoint(41, 92),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: <String, Object>{
        'pressed': false,
        'color': colorName,
        'fault': 'none',
      },
      description: kind == ComponentKind.pushButtonNO
          ? 'نقطة NO تغلق أثناء الضغط ثم تعود تلقائياً.'
          : 'نقطة NC تفتح أثناء الضغط ثم تعود تلقائياً.',
    );
  }
}
