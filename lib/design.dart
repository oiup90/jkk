import 'package:flutter/material.dart';

import 'user_tokens.dart';

const growthPurple = Color(0xff5416e8);
const growthInk = Color(0xff171047);
const growthGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff31118f), Color(0xff3c11b6), Color(0xff742aff)],
);

/// A neutral canvas keeps task content, forms and receipts easy to scan.
class GrowthBackdrop extends StatelessWidget {
  const GrowthBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: userCanvas, child: child);
}

class GrowthIcon extends StatelessWidget {
  const GrowthIcon(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xffeeebfa),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: growthPurple, size: 22),
  );
}

class GrowthArt extends StatelessWidget {
  const GrowthArt(this.name, {super.key, this.height = 170});
  final String name;
  final double height;
  @override
  Widget build(BuildContext context) {
    Widget art = Image.asset(
      'assets/design/$name.png',
      height: height,
      fit: BoxFit.contain,
    );
    if (name.endsWith('_reference')) {
      art = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, .09, .91, 1],
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, .09, .91, 1],
          ).createShader(bounds),
          child: art,
        ),
      );
    }
    return ExcludeSemantics(child: art);
  }
}

class GrowthActionButton extends StatelessWidget {
  const GrowthActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    label: Text(label, textAlign: TextAlign.center),
  );
}

class GrowthPrimaryButton extends StatelessWidget {
  const GrowthPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (icon != null) ...[const SizedBox(width: 12), Icon(icon, size: 19)],
      ],
    ),
  );
}

/// Compact heading for secondary destinations. Content stays left aligned.
class UserSectionIntro extends StatelessWidget {
  const UserSectionIntro({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = growthPurple,
  });
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: userInk,
                  height: 1.25,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: userMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 48,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(5),
            ),
          ),
          child: Icon(icon, color: accent, size: 24),
        ),
      ],
    ),
  );
}

/// A native illustration of the four engagement actions used by this app.
class UserOrbitMark extends StatelessWidget {
  const UserOrbitMark({super.key, this.size = 92});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xffd8cff2)),
              ),
            ),
          ),
          Center(
            child: Container(
              width: size * .62,
              height: size * .62,
              decoration: BoxDecoration(
                color: const Color(0xffede6ff),
                borderRadius: BorderRadius.circular(size * .22),
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: growthPurple,
                size: size * .4,
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _action(Icons.favorite_rounded, const Color(0xffb93e70)),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: _action(Icons.chat_bubble_rounded, userTeal),
          ),
        ],
      ),
    ),
  );
  Widget _action(IconData icon, Color color) => Container(
    width: size * .32,
    height: size * .32,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: userLine),
    ),
    child: Icon(icon, color: color, size: size * .17),
  );
}

class GrowthHero extends StatelessWidget {
  const GrowthHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.art,
    this.background,
    this.action,
    this.minHeight = 0,
  });
  final Widget? action;
  final double minHeight;
  final String title, subtitle;
  final IconData icon;
  final String? art;
  final String? background;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xffede8fc),
      border: Border.all(color: const Color(0xffe0d6f8)),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
        bottomLeft: Radius.circular(8),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: growthPurple, size: 25),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: userInk,
                  fontSize: 24,
                  height: 1.25,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xff615476),
                  height: 1.55,
                  fontSize: 12,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: UserOrbitMark(size: 64),
        ),
      ],
    ),
  );
}

/// Rounded navigation bar used by all four main screens.
class GrowthNavigation extends StatelessWidget {
  const GrowthNavigation({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_outlined,
      Icons.explore_outlined,
      Icons.campaign_outlined,
      Icons.person_outline,
    ];
    const active = [
      Icons.home_rounded,
      Icons.explore,
      Icons.campaign,
      Icons.person,
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: userLine)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected == i,
                        label: labels[i],
                        excludeSemantics: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(i),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected == i
                                          ? const Color(0xffede6ff)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      selected == i ? active[i] : icons[i],
                                      size: 23,
                                      color: selected == i
                                          ? growthPurple
                                          : userMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    labels[i],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.3,
                                      fontWeight: selected == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected == i
                                          ? growthPurple
                                          : userMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GrowthEmpty extends StatelessWidget {
  const GrowthEmpty({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.action,
    this.artHeight = 170,
  });
  final String art, title;
  final String? subtitle;
  final Widget? action;
  final double artHeight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xffece8f8),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xffe1daf2)),
          ),
          child: Icon(
            switch (art) {
              'support' => Icons.forum_outlined,
              'notification_empty' ||
              'notifications' => Icons.notifications_none_rounded,
              'coins' => Icons.toll_outlined,
              _ => Icons.inbox_outlined,
            },
            size: 34,
            color: growthPurple,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: userInk,
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: userMuted, height: 1.6, fontSize: 12),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}
