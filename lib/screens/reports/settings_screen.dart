import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../theme/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _working = false;

  Future<void> _export() async {
    setState(() => _working = true);
    try {
      final db = await AppDatabase.instance;
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      final dbPath = p.join(await getDatabasesPath(), 'fitnesstracker.db');
      final tmp = await getTemporaryDirectory();
      final dest = p.join(tmp.path, 'fitnesstracker_export.db');
      await File(dbPath).copy(dest);
      await Share.shareXFiles([XFile(dest)], text: 'FitnessTracker Database Export');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Database'),
        content: const Text(
            'This will replace ALL current data with the imported file. Make sure you have a backup first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _working = false);
        return;
      }
      final srcPath = result.files.single.path!;
      final dbPath = p.join(await getDatabasesPath(), 'fitnesstracker.db');

      await AppDatabase.reset();

      // Delete WAL/SHM sidecars
      for (final ext in ['-wal', '-shm']) {
        final f = File('$dbPath$ext');
        if (await f.exists()) await f.delete();
      }

      await File(srcPath).copy(dbPath);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text('Import Complete'),
          content: Text('Please force-quit and reopen the app to load the new database.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _working
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('DATA',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                  ),
                  child: Column(
                    children: [
                      _settingsRow(
                        title: 'Export Database',
                        subtitle: 'Share the SQLite file via AirDrop, Files, or any app',
                        icon: Icons.upload,
                        color: AppColors.textPrimary,
                        onTap: _export,
                      ),
                      const Divider(height: 1, indent: 16),
                      _settingsRow(
                        title: 'Import Database',
                        subtitle: 'Replace all data with a previously exported file',
                        icon: Icons.download,
                        color: AppColors.danger,
                        onTap: _import,
                        titleColor: AppColors.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Importing a database replaces all current data. Make sure to export a backup first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
    );
  }

  Widget _settingsRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: titleColor ?? AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
