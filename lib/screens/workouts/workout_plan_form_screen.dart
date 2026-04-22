import 'package:flutter/material.dart';

class WorkoutPlanFormScreen extends StatelessWidget {
  final int? planId;
  const WorkoutPlanFormScreen({super.key, this.planId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(planId == null ? 'New Plan' : 'Edit Plan')),
      body: const Center(child: Text('Workout Plan Form')),
    );
  }
}
