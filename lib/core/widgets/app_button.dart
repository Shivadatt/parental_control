import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.outlined = false,
    this.destructive = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool outlined;
  final bool destructive;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? AppColors.danger : null;
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: destructive
                ? OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: const BorderSide(color: AppColors.danger),
                  )
                : null,
            child: child,
          )
        : FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: child,
          );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
