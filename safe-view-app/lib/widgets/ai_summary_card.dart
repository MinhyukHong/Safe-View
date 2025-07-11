import 'package:flutter/material.dart';

class AiSummaryCard extends StatelessWidget {
  final String summary;

  const AiSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy_outlined),
                SizedBox(width: 8),
                Text("AI 요약 보고서", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            Text(summary, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}