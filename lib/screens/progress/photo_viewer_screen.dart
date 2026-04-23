import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../repositories/progress_photo_repository.dart';
import '../../services/photo_service.dart';
import '../../theme/colors.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  const PhotoViewerScreen({super.key, required this.photos, required this.initialIndex});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  Database? _db;
  late List<Map<String, dynamic>> _photos;
  late int _currentIndex;
  late PageController _pageCtrl;
  bool _showDatePicker = false;
  DateTime _pendingDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _init();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _db = await AppDatabase.instance;
  }

  Map<String, dynamic> get _current => _photos[_currentIndex];

  String get _dateLabel {
    final ds = _current['date'] as String;
    return DateFormat('MMMM d, yyyy').format(DateTime.parse('${ds}T00:00:00'));
  }

  Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('This photo will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = _db!;
    await deletePhoto(db, _current['photoId'] as int);
    await deletePhotoFile(_current['fileUri'] as String);
    final updated = List<Map<String, dynamic>>.from(_photos)..removeAt(_currentIndex);
    if (updated.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    setState(() {
      _photos = updated;
      _currentIndex = _currentIndex.clamp(0, updated.length - 1);
    });
    _pageCtrl.jumpToPage(_currentIndex);
  }

  Future<void> _saveDate() async {
    final db = _db!;
    final newDateStr = DateFormat('yyyy-MM-dd').format(_pendingDate);
    await updatePhotoDate(db, _current['photoId'] as int, newDateStr);
    setState(() {
      _photos[_currentIndex] = Map.from(_current)..['date'] = newDateStr;
      _showDatePicker = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_dateLabel, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () {
              final ds = _current['date'] as String;
              setState(() {
                _pendingDate = DateTime.parse('${ds}T00:00:00');
                _showDatePicker = true;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deletePhoto,
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) => Image.file(
              File(_photos[i]['fileUri'] as String),
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),

          // Dot indicators
          if (_photos.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_photos.length, (i) {
                  final active = i == _currentIndex;
                  return Container(
                    width: active ? 8 : 6,
                    height: active ? 8 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),

          // Date picker overlay
          if (_showDatePicker)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showDatePicker = false),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Change Photo Date',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          CalendarDatePicker(
                            initialDate: _pendingDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            onDateChanged: (d) => setState(() => _pendingDate = d),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _showDatePicker = false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveDate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
