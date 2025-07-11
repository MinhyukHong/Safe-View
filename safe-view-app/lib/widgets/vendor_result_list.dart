import 'package:flutter/material.dart';

class VendorResultList extends StatelessWidget {
  final List<Map<String, dynamic>> vendorResults;

  const VendorResultList({super.key, required this.vendorResults});

  Widget _getIconForCategory(String category) {
    switch (category) {
      case 'harmless':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'malicious':
        return const Icon(Icons.warning, color: Colors.red);
      case 'suspicious':
        return const Icon(Icons.help, color: Colors.orange);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text("Vendor Analysis Results", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...vendorResults.map((result) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            child: ListTile(
              leading: _getIconForCategory(result['category'] ?? ''),
              title: Text(result['vendor_name'] ?? 'Unknown Vendor'),
              subtitle: Text(result['result'] ?? 'No result'),
            ),
          );
        }).toList(),
      ],
    );
  }
}