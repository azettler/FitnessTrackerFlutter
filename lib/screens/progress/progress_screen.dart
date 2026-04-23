import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../repositories/progress_photo_repository.dart';
import '../../services/photo_service.dart';
import '../../theme/colors.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Database? _db;
  // date → photos
  List<({String date, List<ProgressPhoto> photos})> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
    await _load();
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) return;
    final photos = await getRecentPhotos(db);
    final grouped = <String, List<ProgressPhoto>>{};
    for (final p in photos) {
      grouped.putIfAbsent(p.date, () => []).add(p);
    }
    final groups = grouped.entries
        .map((e) => (date: e.key, photos: e.value))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() { _groups = groups; _loading = false; });
  }

  Future<void> _addPhoto() async {
    final source = await _pickSource();
    if (source == null) return;
    final uri = await pickAndSavePhoto(source);
    if (uri == null || !mounted) return;
    // default to today
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await insertPhoto(_db!, today, uri);
    await _load();
  }

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Progress Photos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: _addPhoto,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(
                  child: Text('No photos yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) {
                    final group = _groups[i];
                    return _buildGroup(group.date, group.photos);
                  },
                ),
    );
  }

  Widget _buildGroup(String date, List<ProgressPhoto> photos) {
    final d = DateTime.parse('${date}T00:00:00');
    final label = DateFormat('MMMM d, yyyy').format(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => context.push('/progress/viewer', extra: {
                'photos': photos
                    .map((p) => {'photoId': p.id, 'date': p.date, 'fileUri': p.fileUri})
                    .toList(),
                'initialIndex': i,
              }).then((_) => _load()),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(photos[i].fileUri),
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 130,
                    height: 130,
                    color: AppColors.border,
                    child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
