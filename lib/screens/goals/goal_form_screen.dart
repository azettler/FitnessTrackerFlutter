import 'package:flutter/material.dart';

class GoalFormScreen extends StatelessWidget {
  final int? goalId;
  const GoalFormScreen({super.key, this.goalId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(goalId == null ? 'New Goal' : 'Edit Goal')),
      body: const Center(child: Text('Goal Form')),
    );
  }
}
