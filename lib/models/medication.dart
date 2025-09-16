class Medication {
  final int? id;
  final String name;
  final DateTime firstDose;
  final int intervalMinutes;
  final bool enabled;
  final String? sound;
  final DateTime? autoArchiveAt;

  const Medication({
    this.id,
    required this.name,
    required this.firstDose,
    required this.intervalMinutes,
    required this.enabled,
    this.sound,
    this.autoArchiveAt,
  });

  Medication copyWith({
    int? id,
    String? name,
    DateTime? firstDose,
    int? intervalMinutes,
    bool? enabled,
    String? sound,
    DateTime? autoArchiveAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      firstDose: firstDose ?? this.firstDose,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
      autoArchiveAt: autoArchiveAt == null ? this.autoArchiveAt : autoArchiveAt,
    );
  }

  factory Medication.fromMap(Map<String, Object?> map) {
    final fdRaw = map['first_dose'];
    final firstDose = fdRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(fdRaw)
        : DateTime.now();

    // >>> CORREÇÃO: somar horas*60 + minutos
    final ihRaw = map['interval_hours'];
    final imRaw = map['interval_minutes'];
    final h = ihRaw is int ? ihRaw : 0;
    final mi = imRaw is int ? imRaw : 0;
    final totalIntervalMinutes = (h * 60) + mi;
    final intervalMinutes = totalIntervalMinutes > 0 ? totalIntervalMinutes : 480; // default 8h

    final aaRaw = map['auto_archive_at'];
    final DateTime? autoArchiveAt = aaRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(aaRaw)
        : null;

    return Medication(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Remédio',
      firstDose: firstDose,
      intervalMinutes: intervalMinutes,
      enabled: ((map['enabled'] ?? 1) as int) == 1,
      sound: map['sound'] as String?,
      autoArchiveAt: autoArchiveAt,
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
      'auto_archive_at': autoArchiveAt?.millisecondsSinceEpoch,
    };
  }
}
