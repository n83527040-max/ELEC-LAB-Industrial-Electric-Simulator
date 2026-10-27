import 'geometry.dart';
import 'terminal.dart';

enum WireRouteStyle { orthogonal, straight, curved }

enum WireConductorType { solid, stranded, shielded }

class CircuitWire {
  const CircuitWire({
    required this.id,
    required this.from,
    required this.to,
    required this.layerId,
    this.colorValue = 0xffe53935,
    this.crossSectionMm2 = 1.5,
    this.conductorType = WireConductorType.stranded,
    this.insulationVoltage = 450,
    this.routeStyle = WireRouteStyle.orthogonal,
    this.waypoints = const <BoardPoint>[],
  });

  final String id;
  final TerminalRef from;
  final TerminalRef to;
  final String layerId;
  final int colorValue;
  final double crossSectionMm2;
  final WireConductorType conductorType;
  final int insulationVoltage;
  final WireRouteStyle routeStyle;
  final List<BoardPoint> waypoints;

  bool touches(TerminalRef ref) => from == ref || to == ref;

  CircuitWire copyWith({
    TerminalRef? from,
    TerminalRef? to,
    String? layerId,
    int? colorValue,
    double? crossSectionMm2,
    WireConductorType? conductorType,
    int? insulationVoltage,
    WireRouteStyle? routeStyle,
    List<BoardPoint>? waypoints,
  }) {
    return CircuitWire(
      id: id,
      from: from ?? this.from,
      to: to ?? this.to,
      layerId: layerId ?? this.layerId,
      colorValue: colorValue ?? this.colorValue,
      crossSectionMm2: crossSectionMm2 ?? this.crossSectionMm2,
      conductorType: conductorType ?? this.conductorType,
      insulationVoltage: insulationVoltage ?? this.insulationVoltage,
      routeStyle: routeStyle ?? this.routeStyle,
      waypoints: waypoints ?? this.waypoints,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'from': from.toJson(),
        'to': to.toJson(),
        'layerId': layerId,
        'colorValue': colorValue,
        'crossSectionMm2': crossSectionMm2,
        'conductorType': conductorType.name,
        'insulationVoltage': insulationVoltage,
        'routeStyle': routeStyle.name,
        'waypoints': waypoints.map((point) => point.toJson()).toList(),
      };

  factory CircuitWire.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final layerId = json['layerId'];
    final fromJson = json['from'];
    final toJson = json['to'];
    if (id is! String ||
        id.isEmpty ||
        layerId is! String ||
        fromJson is! Map ||
        toJson is! Map) {
      throw const FormatException('Invalid wire record.');
    }
    final color = json['colorValue'] ?? 0xffe53935;
    final section = json['crossSectionMm2'] ?? 1.5;
    final insulation = json['insulationVoltage'] ?? 450;
    final routeName = json['routeStyle'] ?? WireRouteStyle.orthogonal.name;
    final conductorName =
        json['conductorType'] ?? WireConductorType.stranded.name;
    final waypointsJson = json['waypoints'] ?? const <dynamic>[];
    if (color is! int ||
        section is! num ||
        !section.isFinite ||
        section <= 0 ||
        insulation is! int ||
        insulation <= 0 ||
        waypointsJson is! List) {
      throw const FormatException('Invalid wire properties.');
    }
    final route = WireRouteStyle.values.asNameMap()[routeName];
    final conductor = WireConductorType.values.asNameMap()[conductorName];
    if (route == null || conductor == null) {
      throw const FormatException('Unknown wire style or conductor type.');
    }
    return CircuitWire(
      id: id,
      from: TerminalRef.fromJson(Map<String, dynamic>.from(fromJson)),
      to: TerminalRef.fromJson(Map<String, dynamic>.from(toJson)),
      layerId: layerId,
      colorValue: color,
      crossSectionMm2: section.toDouble(),
      conductorType: conductor,
      insulationVoltage: insulation,
      routeStyle: route,
      waypoints: waypointsJson
          .map(
            (point) => BoardPoint.fromJson(
              Map<String, dynamic>.from(point as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
