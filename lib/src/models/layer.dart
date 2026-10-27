class CircuitLayer {
  const CircuitLayer({
    required this.id,
    required this.name,
    required this.colorValue,
    this.visible = true,
    this.locked = false,
  });

  final String id;
  final String name;
  final int colorValue;
  final bool visible;
  final bool locked;

  CircuitLayer copyWith({
    String? name,
    int? colorValue,
    bool? visible,
    bool? locked,
  }) {
    return CircuitLayer(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'visible': visible,
        'locked': locked,
      };

  factory CircuitLayer.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final color = json['colorValue'];
    final visible = json['visible'] ?? true;
    final locked = json['locked'] ?? false;
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        color is! int ||
        visible is! bool ||
        locked is! bool) {
      throw const FormatException('Invalid layer record.');
    }
    return CircuitLayer(
      id: id,
      name: name,
      colorValue: color,
      visible: visible,
      locked: locked,
    );
  }

  static List<CircuitLayer> defaults() => const <CircuitLayer>[
        CircuitLayer(
          id: 'power',
          name: 'التغذية',
          colorValue: 0xffe53935,
        ),
        CircuitLayer(
          id: 'control',
          name: 'التحكم',
          colorValue: 0xff1e88e5,
        ),
        CircuitLayer(
          id: 'signals',
          name: 'الإشارات',
          colorValue: 0xfffdd835,
        ),
        CircuitLayer(
          id: 'notes',
          name: 'الملاحظات',
          colorValue: 0xff8e24aa,
        ),
      ];
}
