import 'package:flutter/material.dart';

class ExerciseFormScreen extends StatelessWidget {
  final int? exerciseId;
  const ExerciseFormScreen({super.key, this.exerciseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exerciseId == null ? 'New Exercise' : 'Edit Exercise')),
      body: const Center(child: Text('Exercise Form')),
    );
  }
}
