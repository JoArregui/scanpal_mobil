import 'package:flutter/material.dart';

class LectorInfoBar extends StatelessWidget {
  final String ultimoCodigo;
  final VoidCallback onManualEntryTap;

  const LectorInfoBar({
    super.key,
    required this.ultimoCodigo,
    required this.onManualEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      color: Colors.grey[200],
      child: Column(
        children: [
          TextButton.icon(
            onPressed: onManualEntryTap,
            icon: const Icon(Icons.keyboard),
            label: const Text("Entrada Manual"),
            style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
          ),
          Text(
            'Último: $ultimoCodigo',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}