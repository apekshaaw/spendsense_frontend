import 'package:flutter/material.dart';

class NeedsView extends StatelessWidget {
  const NeedsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Needs'),
      ),
      body: const Center(
        child: Text('Needs page'),
      ),
    );
  }
}
