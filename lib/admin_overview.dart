import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_design.dart';

String _text(BuildContext context, String en, String ml) =>
    Localizations.localeOf(context).languageCode == 'ml' ? ml : en;

class AdminOverviewDashboard extends StatefulWidget {
  const AdminOverviewDashboard({
    super.key,
    required this.values,
    required this.trends,
    required this.onNavigate,
    required this.canOpenSupport,
  });

  final Map<String, dynamic> values;
  final List<Map<String, dynamic>> trends;
  final ValueChanged<String> onNavigate;
  final bool canOpenSupport;

  @override
  State<AdminOverviewDashboard> createState() => _AdminOverviewDashboardState();
}

class _AdminOverviewDashboardState extends State<AdminOverviewDashboard> {
  int days = 7;
  String metric = 'registrations';
  int? selectedDay;

  String value(String key) => widget.values[key]?.toString() ?? '—';

  String age(BuildContext context) {
    final timestamp = DateTime.tryParse(
      '${widget.values['oldest_pending_at'] ?? ''}',
    );
    if (timestamp == null) {
      return widget.values['pending_submissions'] == 0
          ? _text(
              context,
              'No pending reviews',
              'പരിശോധിക്കാൻ submissions ഇല്ല',
            )
          : _text(
              context,
              'Oldest time unavailable',
              'പഴയ submission സമയം ലഭ്യമല്ല',
            );
    }
    final elapsed = DateTime.now().toUtc().difference(timestamp.toUtc());
    final minutes = math.max(0, elapsed.inMinutes);
    final time = minutes >= 1440
        ? '${minutes ~/ 1440}d ${(minutes % 1440) ~/ 60}h'
        : minutes >= 60
        ? '${minutes ~/ 60}h ${minutes % 60}m'
        : '${minutes}m';
    return '${_text(context, 'Oldest', 'ഏറ്റവും പഴയത്')}: $time';
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.trends]
      ..sort((a, b) => '${a['day']}'.compareTo('${b['day']}'));
    final visible = items.skip(math.max(0, items.length - days)).toList();
    final chosen = visible.isEmpty
        ? null
        : visible[(selectedDay ?? visible.length - 1).clamp(
            0,
            visible.length - 1,
          )];
    final dayValue = chosen == null
        ? ''
        : metric == 'coins'
        ? '${_text(context, 'Credited', 'ലഭിച്ചത്')}: ${chosen['coins_credited']}  ·  ${_text(context, 'Spent', 'ചെലവായത്')}: ${chosen['coins_spent']}'
        : '${chosen[metric]}';
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return ListView(
      padding: EdgeInsets.all(wide ? 28 : 16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xff211249), Color(0xff6233a9), Color(0xff9462ca)],
            ),
          ),
          child: Wrap(
            spacing: 20,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(context, 'YOUR WORKSPACE', 'ADMIN WORKSPACE'),
                    style: const TextStyle(
                      color: Color(0xffd5c5f4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(context, 'Overview', 'അവലോകനം'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _text(
                      context,
                      'Your platform at a glance',
                      'Platform വിവരങ്ങൾ ഒറ്റനോട്ടത്തിൽ',
                    ),
                    style: const TextStyle(color: Color(0xffe7ddf6)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _text(context, 'TODAY · UTC', 'ഇന്ന് · UTC'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 460
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            final cards = [
              (
                _text(context, 'Users', 'ഉപയോക്താക്കൾ'),
                value('users'),
                Icons.people_outline,
                const Color(0xff7550c8),
              ),
              (
                _text(context, 'Active campaigns', 'സജീവ campaigns'),
                value('active_campaigns'),
                Icons.campaign_outlined,
                const Color(0xff247d91),
              ),
              (
                _text(
                  context,
                  'Pending submissions',
                  'പരിശോധിക്കാനുള്ള submissions',
                ),
                value('pending_submissions'),
                Icons.fact_check_outlined,
                const Color(0xffcf8740),
              ),
              (
                _text(context, 'Coins credited', 'ലഭിച്ച coins'),
                value('coins_credited'),
                Icons.toll_outlined,
                const Color(0xffbb5a86),
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      title: card.$1,
                      value: card.$2,
                      icon: card.$3,
                      color: card.$4,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          _text(context, 'Needs your attention', 'ശ്രദ്ധ ആവശ്യമായവ'),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: adminText),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 600
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _AttentionCard(
                    icon: Icons.support_agent,
                    title: _text(
                      context,
                      'Open support chats',
                      'തുറന്ന support chats',
                    ),
                    count: value('open_support_chats'),
                    detail: _text(
                      context,
                      'Conversations open for support',
                      'Support-നായി തുറന്ന chats',
                    ),
                    onTap: widget.canOpenSupport
                        ? () => widget.onNavigate('operations')
                        : null,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _AttentionCard(
                    icon: Icons.pending_actions,
                    title: _text(
                      context,
                      'Pending reviews',
                      'പരിശോധിക്കാനുള്ള submissions',
                    ),
                    count: value('pending_submissions'),
                    detail: age(context),
                    onTap: () => widget.onNavigate('submissions'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          _text(context, 'Today’s activity', 'ഇന്നത്തെ പ്രവർത്തനം'),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: adminText),
        ),
        const SizedBox(height: 4),
        Text(
          _text(
            context,
            'Counts for the current UTC day',
            'ഇന്നത്തെ UTC ദിവസത്തിലെ കണക്കുകൾ',
          ),
          style: const TextStyle(color: Color(0xff746d86), fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 650
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    title: _text(context, 'New users', 'പുതിയ users'),
                    value: value('today_users'),
                    icon: Icons.person_add_alt_1_outlined,
                    color: const Color(0xff7550c8),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    title: _text(context, 'New campaigns', 'പുതിയ campaigns'),
                    value: value('today_campaigns'),
                    icon: Icons.add_chart,
                    color: const Color(0xff247d91),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    title: _text(
                      context,
                      'Approved submissions',
                      'അംഗീകരിച്ച submissions',
                    ),
                    value: value('today_approved'),
                    icon: Icons.task_alt,
                    color: const Color(0xff4b9777),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(
                          context,
                          'Activity trends',
                          'പ്രവർത്തനത്തിന്റെ വളർച്ച',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: adminText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _text(
                          context,
                          'Daily totals · UTC',
                          'ദിവസേനയുള്ള കണക്കുകൾ · UTC',
                        ),
                        style: const TextStyle(
                          color: Color(0xff746d86),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 days')),
                      ButtonSegment(value: 30, label: Text('30 days')),
                    ],
                    selected: {days},
                    onSelectionChanged: (v) => setState(() {
                      days = v.first;
                      selectedDay = null;
                    }),
                    showSelectedIcon: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in [
                    (
                      'registrations',
                      _text(context, 'Registrations', 'രജിസ്ട്രേഷനുകൾ'),
                    ),
                    ('campaigns', _text(context, 'Campaigns', 'Campaigns')),
                    (
                      'coins',
                      _text(context, 'Coin activity', 'Coin പ്രവർത്തനങ്ങൾ'),
                    ),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: metric == option.$1,
                      onSelected: (_) => setState(() => metric = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                SizedBox(
                  height: 190,
                  child: Center(
                    child: Text(
                      _text(
                        context,
                        'No activity data available.',
                        'പ്രവർത്തന വിവരങ്ങൾ ലഭ്യമല്ല.',
                      ),
                    ),
                  ),
                )
              else ...[
                if (metric == 'coins')
                  Text(
                    _text(
                      context,
                      'Purple: credited   •   Teal: spent',
                      'Purple: ലഭിച്ചത്   •   Teal: ചെലവായത്',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff746d86),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${chosen!['day']}  ·  $dayValue',
                  key: const Key('overview_chart_value'),
                  style: const TextStyle(
                    color: adminText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    void selectAt(double x) {
                      if (visible.length <= 1 || constraints.maxWidth <= 44) {
                        return;
                      }
                      final index =
                          (((x - 36) / (constraints.maxWidth - 44)) *
                                  (visible.length - 1))
                              .round()
                              .clamp(0, visible.length - 1);
                      if (index != selectedDay) {
                        setState(() => selectedDay = index);
                      }
                    }

                    return Semantics(
                      label:
                          '${_text(context, 'Daily activity chart', 'ദിവസേനയുള്ള പ്രവർത്തനം')}: ${chosen['day']}, $dayValue',
                      child: MouseRegion(
                        onHover: (event) => selectAt(event.localPosition.dx),
                        child: GestureDetector(
                          onTapDown: (event) =>
                              selectAt(event.localPosition.dx),
                          child: SizedBox(
                            key: const Key('overview_chart'),
                            height: 210,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _TrendPainter(visible, metric),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _text(context, 'Quick actions', 'വേഗത്തിൽ തുറക്കാം'),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: adminText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => widget.onNavigate('submissions'),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                _text(
                  context,
                  'Pending submissions',
                  'പരിശോധിക്കാനുള്ള submissions',
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.canOpenSupport
                  ? () => widget.onNavigate('operations')
                  : null,
              icon: const Icon(Icons.support_agent),
              label: const Text('Users Supports'),
            ),
            OutlinedButton.icon(
              onPressed: widget.canOpenSupport
                  ? () => widget.onNavigate('walletsManagement')
                  : null,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Wallets Management'),
            ),
          ],
        ),
      ],
    );
  }
}

BoxDecoration _panel() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0xffede9f5)),
  boxShadow: const [
    BoxShadow(color: Color(0x0c281256), blurRadius: 20, offset: Offset(0, 6)),
  ],
);

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 132),
    padding: const EdgeInsets.all(18),
    decoration: _panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: adminText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(color: Color(0xff6c657c), fontSize: 12),
        ),
      ],
    ),
  );
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title, count, detail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffede9f5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xfff1ebfd),
              child: Icon(icon, color: adminAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: adminText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xff746d86),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: adminText,
                fontSize: 24,
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Color(0xff9b8fb0)),
          ],
        ),
      ),
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.rows, this.metric);
  final List<Map<String, dynamic>> rows;
  final String metric;
  double _number(Map<String, dynamic> row, String key) =>
      (row[key] as num?)?.toDouble() ?? 0;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 60 || size.height < 60 || rows.isEmpty) return;
    final keys = metric == 'coins'
        ? ['coins_credited', 'coins_spent']
        : [metric];
    final maxValue = math.max(
      1.0,
      rows
          .expand((r) => keys.map((k) => _number(r, k)))
          .fold<double>(0, math.max),
    );
    const left = 36.0, top = 12.0, bottom = 24.0;
    final width = size.width - left - 8, height = size.height - top - bottom;
    final grid = Paint()
      ..color = const Color(0xffeeeaf5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = top + height * i / 2;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: (maxValue * (1 - i / 2)).round().toString(),
          style: const TextStyle(color: Color(0xff8b829b), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      label.paint(canvas, Offset(0, y - 6));
    }
    for (var j = 0; j < keys.length; j++) {
      final paint = Paint()
        ..color = j == 0 ? const Color(0xff7142cf) : const Color(0xff29a9a4)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < rows.length; i++) {
        final x =
            left +
            (rows.length == 1 ? width / 2 : width * i / (rows.length - 1));
        final y = top + height * (1 - _number(rows[i], keys[j]) / maxValue);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        if (rows.length <= 7) {
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = paint.color);
        }
      }
      canvas.drawPath(path, paint);
    }
    final first = '${rows.first['day']}', last = '${rows.last['day']}';
    for (final label in [(first, left), (last, left + width)]) {
      final painter = TextPainter(
        text: TextSpan(
          text: label.$1,
          style: const TextStyle(color: Color(0xff8b829b), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          label.$2 == left ? left : math.max(left, label.$2 - painter.width),
          size.height - 15,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.metric != metric;
}
