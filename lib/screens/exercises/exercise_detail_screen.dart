import 'package:flutter/material.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final int exerciseId;
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: const Center(child: Text('Exercise Detail')),
    );
  }
}
