enum DoseStatus { taken, missed, skipped }

class DoseEvent {
  final int? id;
  final int medicationId;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime recordedAt;
  final String? note;

  const DoseEvent({
    this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
    required this.recordedAt,
    this.note,
  });

  static DoseStatus statusFromDb(Object? v) {
    final s = (v as String?) ?? 'taken';
    switch (s) {
      case 'missed':
        return DoseStatus.missed;
      case 'skipped':
        return DoseStatus.skipped;
      case 'taken':
      default:
        return DoseStatus.taken;
    }
  }

  static String statusToDb(DoseStatus s) {
    switch (s) {
      case DoseStatus.missed:
        return 'missed';
      case DoseStatus.skipped:
        return 'skipped';
      case DoseStatus.taken:
      default:
        return 'taken';
    }
  }

  factory DoseEvent.fromMap(Map<String, Object?> map) {
    return DoseEvent(
      id: map['id'] as int?,
      medicationId: (map['medication_id'] as int?) ?? 0,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        (map['scheduled_at'] as int?) ?? 0,
      ),
      status: statusFromDb(map['status']),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['recorded_at'] as int?) ?? 0,
      ),
      note: map['note'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'medication_id': medicationId,
    'scheduled_at': scheduledAt.millisecondsSinceEpoch,
    'status': statusToDb(status),
    'recorded_at': recordedAt.millisecondsSinceEpoch,
    'note': note,
  };
}

class DoseEventItem {
  final DoseEvent event;
  final String medicationName;

  const DoseEventItem({
    required this.event,
    required this.medicationName,
  });
}
