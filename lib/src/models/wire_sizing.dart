enum ConductorMaterial { copper, aluminum }

enum CableUsage { control, power }

class WireSizingInput {
  const WireSizingInput({
    required this.expectedCurrent,
    required this.material,
    required this.usage,
    required this.ambientTemperature,
    required this.groupedInConduit,
  });

  final double expectedCurrent;
  final ConductorMaterial material;
  final CableUsage usage;
  final double ambientTemperature;
  final bool groupedInConduit;
}

class WireSizingSuggestion {
  const WireSizingSuggestion({
    required this.sectionMm2,
    required this.designCurrent,
    required this.deratingFactor,
    required this.disclaimerAr,
  });

  final double sectionMm2;
  final double designCurrent;
  final double deratingFactor;
  final String disclaimerAr;
}

/// Educational rule table only. It is deliberately not presented as standards
/// compliance and requires explicit current/material/conditions inputs.
abstract final class EducationalWireSizing {
  static const _sections = <double>[0.5, 0.75, 1, 1.5, 2.5, 4, 6, 10, 16, 25];
  static const _copperCapacity = <double>[6, 8, 10, 14, 20, 26, 34, 46, 63, 85];

  static WireSizingSuggestion? suggest(WireSizingInput input) {
    if (!input.expectedCurrent.isFinite ||
        input.expectedCurrent <= 0 ||
        !input.ambientTemperature.isFinite ||
        input.ambientTemperature < -20 ||
        input.ambientTemperature > 80) {
      return null;
    }
    final designCurrent = input.expectedCurrent * 1.25;
    var derating = 1.0;
    if (input.ambientTemperature > 30) derating *= 0.9;
    if (input.groupedInConduit) derating *= 0.9;
    if (input.material == ConductorMaterial.aluminum) derating *= 0.75;
    if (input.usage == CableUsage.control && designCurrent < 1) {
      return WireSizingSuggestion(
        sectionMm2: 0.5,
        designCurrent: designCurrent,
        deratingFactor: derating,
        disclaimerAr: _disclaimer,
      );
    }
    for (var index = 0; index < _sections.length; index++) {
      if (_copperCapacity[index] * derating >= designCurrent) {
        return WireSizingSuggestion(
          sectionMm2: _sections[index],
          designCurrent: designCurrent,
          deratingFactor: derating,
          disclaimerAr: _disclaimer,
        );
      }
    }
    return null;
  }

  static const _disclaimer =
      'اقتراح تعليمي مبسط وليس اختياراً آمناً أو مطابقة لمعيار؛ يلزم مهندس مؤهل ومراجعة طول الكابل والحماية وطريقة التمديد والمعايير المحلية.';
}
