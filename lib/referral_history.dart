import 'package:flutter/material.dart';

import 'user_localization.dart';
import 'user_page_canvas.dart';

class ReferralHistoryEntry {
  ReferralHistoryEntry.fromRow(Map row)
    : referred = row['direction'] == 'referred',
      name = row['masked_name'] as String?,
      email = row['masked_email'] as String?,
      date = DateTime.parse(row['created_at'] as String).toLocal();

  final bool referred;
  final String? name, email;
  final DateTime date;
}

abstract interface class ReferralHistoryGateway {
  Future<List<ReferralHistoryEntry>> loadReferralHistory(int offset);
}

class ReferralHistoryPage extends StatefulWidget {
  const ReferralHistoryPage({super.key, required this.load});

  final Future<List<ReferralHistoryEntry>> Function(int offset) load;

  @override
  State<ReferralHistoryPage> createState() => _ReferralHistoryPageState();
}

class _ReferralHistoryPageState extends State<ReferralHistoryPage> {
  static const pageSize = 50;
  int offset = 0;
  late var data = widget.load(offset);

  void page(int next) => setState(() {
    offset = next;
    data = widget.load(offset);
  });

  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.referrals,
    appBar: AppBar(
      title: Text(userText(context, 'Referral History', 'Referral ചരിത്രം')),
    ),
    body: FutureBuilder<List<ReferralHistoryEntry>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userText(
                    context,
                    'Unable to load referral history.',
                    'Referral ചരിത്രം ലഭ്യമല്ല.',
                  ),
                ),
                TextButton(
                  onPressed: () => page(offset),
                  child: Text(userText(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക')),
                ),
              ],
            ),
          );
        }
        final entries = snapshot.data!;
        final dates = MaterialLocalizations.of(context);
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (entries.isEmpty)
              Text(
                userText(
                  context,
                  'No referrals on this page.',
                  'ഈ പേജിൽ referrals ഇല്ല.',
                ),
              ),
            for (final entry in entries)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    entry.name ??
                        userText(context, 'Name unavailable', 'പേര് ലഭ്യമല്ല'),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.email != null)
                        Text(entry.email!, textDirection: TextDirection.ltr),
                      Text(
                        entry.referred
                            ? userText(
                                context,
                                'Used your code',
                                'നിങ്ങളുടെ code ഉപയോഗിച്ചു',
                              )
                            : userText(
                                context,
                                'Referred you',
                                'നിങ്ങളെ refer ചെയ്തു',
                              ),
                      ),
                      Text(dates.formatMediumDate(entry.date)),
                    ],
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (offset > 0)
                  TextButton(
                    onPressed: () => page(offset - pageSize),
                    child: Text(
                      userText(context, 'Previous', 'മുമ്പത്തെ പേജ്'),
                    ),
                  ),
                if (entries.length == pageSize)
                  TextButton(
                    onPressed: () => page(offset + pageSize),
                    child: Text(userText(context, 'Next', 'അടുത്ത പേജ്')),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class CampaignPlan {
  const CampaignPlan({
    required this.maxTasks,
    this.nextCampaignAt,
    this.campaignCount = 1,
    this.windowHours = 24,
    this.baseTasks = 3,
    this.referralBonus = 5,
  });

  factory CampaignPlan.fromJson(Map data) => CampaignPlan(
    maxTasks: data['max_tasks'] as int,
    nextCampaignAt: data['next_campaign_at'] == null
        ? null
        : DateTime.parse(data['next_campaign_at'] as String),
    campaignCount: data['campaign_count'] as int,
    windowHours: data['window_hours'] as int,
    baseTasks: data['base_tasks'] as int,
    referralBonus: data['referral_bonus'] as int,
  );

  final int maxTasks, campaignCount, windowHours, baseTasks, referralBonus;
  final DateTime? nextCampaignAt;
}

abstract interface class CampaignPlanGateway {
  Future<CampaignPlan> loadCampaignPlan();
}

class CampaignLimitsPage extends StatefulWidget {
  const CampaignLimitsPage({super.key, required this.loadPlan});
  final Future<CampaignPlan> Function() loadPlan;

  @override
  State<CampaignLimitsPage> createState() => _CampaignLimitsPageState();
}

class _CampaignLimitsPageState extends State<CampaignLimitsPage> {
  late Future<CampaignPlan> plan = widget.loadPlan();
  @override
  Widget build(BuildContext context) => UserPageScaffold(
    identity: UserPageIdentity.profile,
    appBar: AppBar(
      title: Text(userText(context, 'Campaign Limits', 'Campaign പരിധികൾ')),
    ),
    body: FutureBuilder<CampaignPlan>(
      future: plan,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userText(
                    context,
                    'Unable to load campaign limits.',
                    'Campaign പരിധികൾ ലഭ്യമല്ല.',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    plan = widget.loadPlan();
                  }),
                  child: Text(userText(context, 'Retry', 'വീണ്ടും ശ്രമിക്കുക')),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final value = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed_outlined),
                title: Text(userText(context, 'Free Plan', 'Free Plan')),
                subtitle: Text(
                  userText(
                    context,
                    '${value.campaignCount} campaign(s) every ${value.windowHours} hours',
                    '${value.windowHours} മണിക്കൂറിൽ ${value.campaignCount} campaign(s)',
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist),
                title: Text(
                  userText(
                    context,
                    '${value.baseTasks} tasks per campaign',
                    'ഒരു campaign-ന് ${value.baseTasks} tasks',
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(
                  userText(
                    context,
                    '${value.referralBonus} extra tasks with a referral',
                    'Referral വഴി ${value.referralBonus} extra tasks',
                  ),
                ),
                subtitle: Text(
                  userText(
                    context,
                    'After your first successful referral, you can add up to ${value.baseTasks + value.referralBonus} tasks per campaign.',
                    'ആദ്യ successful referral കഴിഞ്ഞാൽ ഒരു campaign-ന് ${value.baseTasks + value.referralBonus} tasks വരെ ചേർക്കാം.',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
