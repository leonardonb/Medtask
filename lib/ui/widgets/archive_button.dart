import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/notification_helpers.dart';
import '../../core/notification_service.dart';
import '../../data/services/archive_service.dart';
import '../../viewmodels/med_list_viewmodel.dart';

class ArchiveButton extends StatefulWidget {
  final int medId;
  final VoidCallback? onArchived;

  const ArchiveButton({super.key, required this.medId, this.onArchived});

  @override
  State<ArchiveButton> createState() => _ArchiveButtonState();
}

class _ArchiveButtonState extends State<ArchiveButton> {
  final _svc = ArchiveService();
  bool _busy = false;

  Future<void> _archive() async {
    if (_busy) return;
    setState(() => _busy = true);

    await _svc.archive(widget.medId);

    await NotificationService.cancelSeries(widget.medId * 1000, 12);
    await NotificationHelpers.cancelAllForMed(widget.medId, maxPerMed: 16);

    if (Get.isRegistered<MedListViewModel>()) {
      await Get.find<MedListViewModel>().init();
    }

    setState(() => _busy = false);
    widget.onArchived?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicamento arquivado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Arquivar',
      icon: _busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.archive),
      onPressed: _busy ? null : _archive,
    );
  }
}
