import 'package:flutter/material.dart';

class PhotoViewerScreen extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  const PhotoViewerScreen({super.key, required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo')),
      body: const Center(child: Text('Photo Viewer')),
    );
  }
}
