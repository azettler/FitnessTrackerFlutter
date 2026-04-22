import 'package:flutter/material.dart';

class ScheduleFormScreen extends StatelessWidget {
  final int planId;
  final int? scheduleId;
  const ScheduleFormScreen({super.key, required this.planId, this.scheduleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(scheduleId == null ? 'Add Schedule' : 'Edit Schedule')),
      body: const Center(child: Text('Schedule Form')),
    );
  }
}
