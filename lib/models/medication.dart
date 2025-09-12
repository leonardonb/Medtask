class Medication {
  final int? id;
  final String name;
  final DateTime firstDose;
  final int intervalMinutes;
  final bool enabled;
  final String? sound;

  const Medication({
    this.id,
    required this.name,
    required this.firstDose,
    required this.intervalMinutes,
    required this.enabled,
    this.sound,
  });

  Medication copyWith({
    int? id,
    String? name,
    DateTime? firstDose,
    int? intervalMinutes,
    bool? enabled,
    String? sound,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      firstDose: firstDose ?? this.firstDose,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
    );
  }

  factory Medication.fromMap(Map<String, Object?> map) {
    final fdRaw = map['first_dose'];
    final firstDose = fdRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(fdRaw)
        : DateTime.now();

    final imRaw = map['interval_minutes'];
    final ihRaw = map['interval_hours'];
    final intervalMinutes = imRaw is int
        ? imRaw
        : (ihRaw is int ? ihRaw * 60 : 480); // default 8h

    return Medication(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Remédio',
      firstDose: firstDose,
      intervalMinutes: intervalMinutes,
      enabled: ((map['enabled'] ?? 1) as int) == 1,
      sound: map['sound'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'first_dose': firstDose.millisecondsSinceEpoch,
      'interval_minutes': intervalMinutes,
      'enabled': enabled ? 1 : 0,
      'sound': sound,
    };
  }
}
