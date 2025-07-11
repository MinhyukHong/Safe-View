import 'package:flutter/material.dart';

class RiskSummaryCard extends StatelessWidget {
  final String riskLevel;
  final String summary;

  const RiskSummaryCard({
    super.key,
    required this.riskLevel,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk Level: $riskLevel', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(summary),
          ],
        ),
      ),
    );
  }
}