import 'package:flutter/material.dart';

class DayDetailScreen extends StatelessWidget {
  final String date;
  const DayDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(date)),
      body: const Center(child: Text('Day Detail')),
    );
  }
}
