import 'package:flutter/material.dart';

class ExercisePickerScreen extends StatelessWidget {
  final Map<String, dynamic> extra;
  const ExercisePickerScreen({super.key, required this.extra});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Exercises')),
      body: const Center(child: Text('Exercise Picker')),
    );
  }
}
