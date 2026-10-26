import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'status_chip.dart';

class PermissionStatusTile extends StatelessWidget {
  const PermissionStatusTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.granted,
    this.isUnknown = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final bool granted;
  final bool isUnknown;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tone = isUnknown
        ? StatusTone.neutral
        : (granted ? StatusTone.success : StatusTone.warning);
    final label = isUnknown ? 'Unknown' : (granted ? 'Granted' : 'Required');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: granted ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          else
            StatusChip(label: label, tone: tone),
        ],
      ),
    );
  }
}
