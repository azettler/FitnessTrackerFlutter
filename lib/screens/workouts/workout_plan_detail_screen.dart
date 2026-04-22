import 'package:flutter/material.dart';

class WorkoutPlanDetailScreen extends StatelessWidget {
  final int planId;
  const WorkoutPlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Plan')),
      body: const Center(child: Text('Workout Plan Detail')),
    );
  }
}
