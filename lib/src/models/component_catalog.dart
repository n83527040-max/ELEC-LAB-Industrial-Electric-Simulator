import 'dart:ui' show Size;

import 'component.dart';
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
          label: '+24V',
          position: BoardPoint(32, 0),
          kind: TerminalKind.power,
        ),
        TerminalDefinition(
          id: 'negative',
          label: '0V',
          position: BoardPoint(80, 0),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'voltage': 24.0,
        'internalResistance': 0.05,
        'enabled': true,
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
          position: BoardPoint(32, 0),
          kind: TerminalKind.power,
          phase: 'L',
        ),
        TerminalDefinition(
          id: 'neutral',
          label: 'N',
          position: BoardPoint(80, 0),
          kind: TerminalKind.neutral,
        ),
      ],
      defaultProperties: const <String, Object>{
        'voltage': 24.0,
        'frequency': 50.0,
        'internalResistance': 0.05,
        'enabled': true,
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
          position: BoardPoint(24, 0),
          kind: TerminalKind.power,
          phase: 'L1',
        ),
        TerminalDefinition(
          id: 'l2',
          label: 'L2',
          position: BoardPoint(56, 0),
          kind: TerminalKind.power,
          phase: 'L2',
        ),
        TerminalDefinition(
          id: 'l3',
          label: 'L3',
          position: BoardPoint(88, 0),
          kind: TerminalKind.power,
          phase: 'L3',
        ),
        TerminalDefinition(
          id: 'neutral',
          label: 'N',
          position: BoardPoint(120, 0),
          kind: TerminalKind.neutral,
        ),
        TerminalDefinition(
          id: 'pe',
          label: 'PE',
          position: BoardPoint(120, 126),
          kind: TerminalKind.earth,
        ),
      ],
      defaultProperties: const <String, Object>{
        'lineVoltage': 400.0,
        'frequency': 50.0,
        'internalResistance': 0.05,
        'enabled': true,
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
      description: 'مسارا قدرة L1/T1 وL3/T3 ونقطة NC تفتح عند الحمل الزائد.',
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
          id: 't18',
          label: '18NO',
          position: BoardPoint(0, 96),
          kind: TerminalKind.auxiliary,
        ),
      ],
      defaultProperties: const <String, Object>{
        'coilVoltage': 24.0,
        'coilResistance': 300.0,
        'delaySeconds': 3.0,
        'fault': 'none',
      },
      description: 'يغلق 15/18 بعد استمرار تغذية الملف طوال الزمن المحدد.',
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
