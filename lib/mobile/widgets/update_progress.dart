import 'package:flutter/material.dart';

class UpdateProgress extends StatelessWidget {
  final int progress;

  const UpdateProgress({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: Colors.grey[200],
        ),
        const SizedBox(height: 8),
        Text('$progress%'),
      ],
    );
  }
}