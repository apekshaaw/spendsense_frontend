import 'package:flutter/material.dart';

class AddGoalView extends StatelessWidget {
  const AddGoalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Goal'),
      ),
      body: const Center(
        child: Text('Add Goal page'),
      ),
    );
  }
}
