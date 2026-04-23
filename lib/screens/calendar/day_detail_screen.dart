import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/exempt_day_repository.dart';
import '../../repositories/instance_repository.dart';
import '../../repositories/progress_photo_repository.dart';
import '../../services/photo_service.dart';
import '../../theme/colors.dart';

class DayDetailScreen extends StatefulWidget {
  final String date;
  const DayDetailScreen({super.key, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  Database? _db;
  List<WorkoutInstance> _instances = [];
  List<ProgressPhoto> _photos = [];
  ExemptDay? _exemptDay;
  bool _loading = true;

  late final DateTime _parsedDate;
  late final String _displayDate;

  @override
  void initState() {
    super.initState();
    _parsedDate = DateTime.parse('${widget.date}T00:00:00');
    _displayDate = DateFormat('EEEE, MMMM d, yyyy').format(_parsedDate);
    _init();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    await _load();
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) return;
    final instances = await getInstancesForDate(db, widget.date);
    final photos = await getPhotosForDate(db, widget.date);
    final exempt = await getExemptDay(db, widget.date);
    if (mounted) {
      setState(() {
        _instances = instances;
        _photos = photos;
        _exemptDay = exempt;
        _loading = false;
      });
    }
  }

  Future<void> _toggleExempt() async {
    final db = _db;
    if (db == null) return;
    if (_exemptDay != null) {
      await removeExemptDay(db, widget.date);
    } else {
      await setExemptDay(db, widget.date, null);
    }
    await _load();
  }

  Future<void> _addPhoto() async {
    final source = await _pickSource();
    if (source == null) return;
    final uri = await pickAndSavePhoto(source);
    if (uri == null || !mounted) return;
    await insertPhoto(_db!, widget.date, uri);
    await _load();
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(WorkoutInstanceStatus s) {
    switch (s) {
      case WorkoutInstanceStatus.complete:
        return AppColors.statusComplete;
      case WorkoutInstanceStatus.partial:
        return AppColors.statusPartial;
      case WorkoutInstanceStatus.pending:
        return AppColors.statusScheduled;
      case WorkoutInstanceStatus.skipped:
        return AppColors.statusSkipped;
    }
  }

  String _statusLabel(WorkoutInstanceStatus s) {
    switch (s) {
      case WorkoutInstanceStatus.complete:
        return 'Complete';
      case WorkoutInstanceStatus.partial:
        return 'Partial';
      case WorkoutInstanceStatus.pending:
        return 'Scheduled';
      case WorkoutInstanceStatus.skipped:
        return 'Skipped';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          DateFormat('MMM d, yyyy').format(_parsedDate),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _displayDate,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Workout instances
                ..._instances.map((inst) => _buildInstanceCard(inst)),

                // Exempt toggle
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _toggleExempt,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _exemptDay != null ? AppColors.statusSkipped : AppColors.border,
                    ),
                    foregroundColor: _exemptDay != null ? AppColors.statusSkipped : AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_exemptDay != null ? 'Remove Exempt Day' : 'Mark as Exempt'),
                ),

                const SizedBox(height: 24),

                // Progress photos section
                const Text(
                  'PROGRESS PHOTOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),

                if (_photos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No photos for this day',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (context2, i2) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => context.push('/calendar/day/${widget.date}/photo-viewer',
                            extra: {
                              'photos': _photos
                                  .map((p) => {
                                        'photoId': p.id,
                                        'date': p.date,
                                        'fileUri': p.fileUri,
                                      })
                                  .toList(),
                              'initialIndex': i,
                            }).then((_) => _load()),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photos[i].fileUri),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 80,
                              height: 80,
                              color: AppColors.border,
                              child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _addPhoto,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('+ Add Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
    );
  }

  Widget _buildInstanceCard(WorkoutInstance inst) {
    final color = _statusColor(inst.status);
    final label = _statusLabel(inst.status);
    return GestureDetector(
      onTap: () => context
          .push('/calendar/day/${widget.date}/instance/${inst.id}')
          .then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                inst.workoutPlanName ?? 'Workout',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
