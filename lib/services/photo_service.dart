import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _picker = ImagePicker();

Future<String?> pickAndSavePhoto(ImageSource source) async {
  final xFile = await _picker.pickImage(source: source, imageQuality: 90);
  if (xFile == null) return null;

  final dir = await getApplicationDocumentsDirectory();
  final photoDir = Directory(p.join(dir.path, 'progress'));
  if (!await photoDir.exists()) await photoDir.create(recursive: true);

  final ext = p.extension(xFile.path).isNotEmpty ? p.extension(xFile.path) : '.jpg';
  final dest = p.join(photoDir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
  await File(xFile.path).copy(dest);
  return dest;
}

Future<void> deletePhotoFile(String fileUri) async {
  try {
    final f = File(fileUri);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
