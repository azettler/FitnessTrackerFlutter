import 'package:flutter/material.dart';

class WorkoutInstanceScreen extends StatelessWidget {
  final int instanceId;
  const WorkoutInstanceScreen({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: const Center(child: Text('Workout Instance')),
    );
  }
}
