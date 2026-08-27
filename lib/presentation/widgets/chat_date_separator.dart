import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/date_time_formatter.dart';

class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Text(
            DateTimeFormatter.formatDateHeader(date),
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
