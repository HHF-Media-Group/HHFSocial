import 'package:flutter/material.dart';

/// Shared bottom sheet for picking a report reason.
/// Returns the selected reason, or null if dismissed.
class ReportContentSheet {
  static const List<String> _reasons = [
    'Spam',
    'Nudity or sexual content',
    'Harassment or bullying',
    'Hate speech',
    'Violence or dangerous content',
    'Other',
  ];

  static Future<String?> show(BuildContext context, {required String title}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Why are you reporting this?',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 8),
            ..._reasons.map(
              (reason) => ListTile(
                dense: true,
                leading: const Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                title: Text(reason, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, reason),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
