import 'package:flutter/material.dart';

import 'design.dart';

class DashboardTaskTile extends StatelessWidget {
  const DashboardTaskTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffe9e2f2)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const Spacer(),
                const Icon(
                  Icons.north_east,
                  size: 16,
                  color: Color(0xff8a779d),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: const TextStyle(
                color: growthInk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xff6d6580),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EarnEmptyState extends StatelessWidget {
  const EarnEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  final String title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffe9e2f2)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xfff1ebfc),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.inbox_outlined,
            color: growthPurple,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: growthInk,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xff6d6580),
            fontSize: 11,
            height: 1.5,
          ),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!, textAlign: TextAlign.center),
          ),
        ],
      ],
    ),
  );
}
