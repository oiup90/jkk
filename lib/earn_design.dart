import 'package:flutter/material.dart';

import 'design.dart';
import 'user_tokens.dart';

class EarnCategoryTile extends StatelessWidget {
  const EarnCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: userLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: growthInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: userMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              color: const Color(0xff8a779d),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Presentation for the Earn page; task availability remains server-derived.
class EarnHero extends StatelessWidget {
  const EarnHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });
  final String title, subtitle, actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => GrowthHero(
    title: title,
    subtitle: subtitle,
    icon: Icons.explore_outlined,
    action: FilledButton.icon(
      onPressed: onAction,
      icon: const Icon(Icons.grid_view_rounded, size: 18),
      label: Text(actionLabel),
    ),
  );
}

class EarnSectionHeader extends StatelessWidget {
  const EarnSectionHeader({super.key, required this.title, this.count});
  final String title;
  final int? count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: growthInk,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (count != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xffede5fa),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: growthPurple,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );
}

/// Visual shell for a task. Actions and status are supplied by the existing flow.
class EarnTaskCard extends StatelessWidget {
  const EarnTaskCard({
    super.key,
    required this.icon,
    required this.title,
    required this.reward,
    required this.link,
    required this.saveTooltip,
    required this.saved,
    required this.onSave,
    required this.actions,
    this.status,
    this.disabledMessage,
  });
  final IconData icon;
  final String title, reward, link, saveTooltip;
  final bool saved;
  final VoidCallback? onSave;
  final Widget actions;
  final Widget? status;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: userLine),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xffede8fc),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: growthPurple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: growthInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff4d9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        reward,
                        style: const TextStyle(
                          color: Color(0xff78510c),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: saveTooltip,
                onPressed: onSave,
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xfff5f0fc),
                  foregroundColor: growthPurple,
                  minimumSize: const Size(44, 44),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xfff7f4fb),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.link_rounded,
                  color: Color(0xff8068a0),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    link,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff57486c),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...[const SizedBox(height: 12), status!],
          if (disabledMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              disabledMessage!,
              style: const TextStyle(color: Color(0xff755315)),
            ),
          ],
          const SizedBox(height: 14),
          actions,
        ],
      ),
    ),
  );
}
