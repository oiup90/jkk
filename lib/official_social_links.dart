import 'package:flutter/material.dart';

import 'auth_languages.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const socialPlatforms = <String, String>{
  'instagram': 'Instagram',
  'facebook': 'Facebook',
  'youtube': 'YouTube',
  'x': 'X',
};
const _hosts = <String, Set<String>>{
  'instagram': {'instagram.com', 'www.instagram.com'},
  'facebook': {'facebook.com', 'www.facebook.com'},
  'youtube': {'youtube.com', 'www.youtube.com', 'youtu.be'},
  'x': {'x.com', 'www.x.com', 'twitter.com', 'www.twitter.com'},
};
bool validOfficialSocialUrl(String platform, String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      (_hosts[platform]?.contains(uri.host.toLowerCase()) ?? false);
}

typedef LoadSocialLinks = Future<List<Map<String, dynamic>>> Function();
Future<List<Map<String, dynamic>>> loadOfficialSocialLinks(
  SupabaseClient client,
) async =>
    (await client.from('official_social_links').select('platform,url') as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

class OfficialSocialLinks extends StatefulWidget {
  const OfficialSocialLinks({super.key, required this.load, this.open});
  final LoadSocialLinks load;
  final Future<bool> Function(Uri)? open;
  @override
  State<OfficialSocialLinks> createState() => _OfficialSocialLinksState();
}

class _OfficialSocialLinksState extends State<OfficialSocialLinks> {
  late Future<List<Map<String, dynamic>>> links = widget.load();
  @override
  void didUpdateWidget(covariant OfficialSocialLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) links = widget.load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: links,
    builder: (context, snapshot) {
      final links = (snapshot.data ?? [])
          .where(
            (e) =>
                e['platform'] is String &&
                e['url'] is String &&
                validOfficialSocialUrl(
                  e['platform'] as String,
                  e['url'] as String,
                ),
          )
          .toList();
      if (links.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Freelan Space · ${authTranslations[Localizations.localeOf(context).languageCode]?['official'] ?? (Localizations.localeOf(context).languageCode == 'ml' ? 'ഔദ്യോഗികം' : 'Official')}',
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (final link in links)
                TextButton(
                  onPressed: () async {
                    final uri = Uri.parse(link['url'] as String);
                    try {
                      final launched =
                          await (widget.open?.call(uri) ??
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              ));
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authTranslations[Localizations.localeOf(context)
                                      .languageCode]?['openFailed'] ??
                                  'Unable to open link.',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authTranslations[Localizations.localeOf(context)
                                      .languageCode]?['openFailed'] ??
                                  'Unable to open link.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(socialPlatforms[link['platform']]!),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class AdminSocialLinksPage extends StatefulWidget {
  const AdminSocialLinksPage({
    super.key,
    required this.client,
    required this.canEdit,
  });
  final SupabaseClient client;
  final bool canEdit;
  @override
  State<AdminSocialLinksPage> createState() => _AdminSocialLinksPageState();
}

class _AdminSocialLinksPageState extends State<AdminSocialLinksPage> {
  final fields = {
    for (final key in socialPlatforms.keys) key: TextEditingController(),
  };
  bool loading = true, busy = false, failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final rows = await loadOfficialSocialLinks(widget.client);
      if (!mounted) return;
      for (final e in rows) {
        if (fields.containsKey(e['platform'])) {
          fields[e['platform']]!.text = e['url'] as String;
        }
      }
    } catch (_) {
      failed = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save(String platform) async {
    final url = fields[platform]!.text.trim();
    if (url.isNotEmpty && !validOfficialSocialUrl(platform, url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid HTTPS URL for this platform.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'admin_set_social_link',
        params: {'p_platform': platform, 'p_url': url},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Official link saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save. Check access and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Official social links')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : failed
            ? Center(
                child: TextButton(
                  onPressed: load,
                  child: const Text('Unable to load. Retry'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Add official profile links shown on the sign-in page. Clear a field and save to remove it.',
                  ),
                  for (final entry in socialPlatforms.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: fields[entry.key],
                              enabled: widget.canEdit && !busy,
                              maxLength: 500,
                              decoration: InputDecoration(
                                labelText: entry.value,
                                hintText: 'https://',
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: widget.canEdit && !busy
                                ? () => save(entry.key)
                                : null,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  if (!widget.canEdit) const Text('Read-only access'),
                ],
              ),
      ),
    ),
  );
}
