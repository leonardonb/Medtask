class DoseLog {
  final int? id;
  final int medicationId;
  final DateTime takenAt;

  DoseLog({this.id, required this.medicationId, required this.takenAt});

  Map<String, Object?> toMap() => {
    'id': id,
    'medication_id': medicationId,
    'taken_at': takenAt.millisecondsSinceEpoch,
  };
}
