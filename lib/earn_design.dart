import 'package:flutter/material.dart';

import 'design.dart';

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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff3e1c80).withValues(alpha: .2),
          blurRadius: 20,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff38205f), Color(0xff57328c), Color(0xff764bbb)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -45,
              top: -60,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Container(
                    width: 175,
                    height: 175,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .09),
                        width: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0x26f4dca8),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0x66f4dca8)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xfff5dfb2),
                      size: 21,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xffeee5f8),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                    label: Text(actionLabel),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xfff3dfb4),
                      foregroundColor: const Color(0xff342044),
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: growthPurple,
              fontSize: 11,
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
      border: Border.all(color: const Color(0xffe8def3)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff3e1c80).withValues(alpha: .07),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
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
                  gradient: const LinearGradient(
                    colors: [Color(0xffeee4fc), Color(0xffe0cff7)],
                  ),
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
                          fontSize: 11,
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
                      fontSize: 11,
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
