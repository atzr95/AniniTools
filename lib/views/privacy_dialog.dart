import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reporting_preferences.dart';

class PrivacyDialog extends StatefulWidget {
  const PrivacyDialog({super.key, required this.reporting});

  final ReportingPreferences reporting;

  @override
  State<PrivacyDialog> createState() => _PrivacyDialogState();
}

class _PrivacyDialogState extends State<PrivacyDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _changeChoice(bool enabled) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.reporting.setEnabled(enabled);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not change the reporting choice. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy & data'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: widget.reporting,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reports are off until you choose to share them. '
                  'All tools work with reports off.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share optional app reports'),
                  value: widget.reporting.enabled,
                  onChanged: _saving ? null : _changeChoice,
                ),
                const Text(
                  'If on, Google receives screen use, app and device IDs, '
                  'device details, approximate location from your internet '
                  'address, and crash reports. We use these to understand '
                  'use and fix faults. This does not send your microphone '
                  'audio, GPS coordinates, messages or favorites.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Turn this off here at any time to stop future reports. '
                  'This does not erase reports already sent to Google.',
                ),
                if (_saving) const Text('Saving your choice…'),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                const SelectableText('Support: aniniwtf@gmail.com'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const PrivacyPolicyDialog(),
          ),
          child: const Text('Privacy policy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class PrivacyPolicyDialog extends StatefulWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  String _language = 'en';
  late Future<String> _policy = _loadPolicy();

  Future<String> _loadPolicy() =>
      rootBundle.loadString('assets/privacy/$_language.txt');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy policy / Notis privasi'),
      content: SizedBox(
        width: 640,
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            DropdownButton<String>(
              isExpanded: true,
              value: _language,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ms', child: Text('Bahasa Malaysia')),
              ],
              onChanged: (language) {
                if (language == null) return;
                setState(() {
                  _language = language;
                  _policy = _loadPolicy();
                });
              },
            ),
            Expanded(
              child: FutureBuilder<String>(
                future: _policy,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return TextButton(
                      onPressed: () => setState(() => _policy = _loadPolicy()),
                      child: const Text(
                        'Could not load the policy. Try again.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    key: ValueKey(_language),
                    child: SelectableText(snapshot.data!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
