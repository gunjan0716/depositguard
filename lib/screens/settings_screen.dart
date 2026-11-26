import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PageFrame(
      title: 'Settings',
      subtitle: 'Role, appearance, deduction rules and data',
      children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Using the app as'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<Role>(
                  segments: const [
                    ButtonSegment(value: Role.tenant, label: Text('Tenant')),
                    ButtonSegment(value: Role.landlord, label: Text('Landlord')),
                  ],
                  selected: {s.role},
                  onSelectionChanged: (v) => s.setRole(v.first),
                ),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: s.themeMode == ThemeMode.dark,
              onChanged: (v) => s.setTheme(v ? ThemeMode.dark : ThemeMode.light),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.balance),
              title: const Text('Wear & tear rule'),
              subtitle: Text('1 condition level is free for every ${s.monthsPerWearLevel} months'),
              trailing: DropdownButton<int>(
                value: s.monthsPerWearLevel,
                items: const [
                  DropdownMenuItem(value: 6, child: Text('6 months')),
                  DropdownMenuItem(value: 12, child: Text('12 months')),
                  DropdownMenuItem(value: 18, child: Text('18 months')),
                  DropdownMenuItem(value: 24, child: Text('24 months')),
                ],
                onChanged: (v) => s.setWearRule(v ?? 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Copy backup (JSON)'),
              subtitle: const Text('Paste it into an email or notes app to keep a copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text: const JsonEncoder.withIndent('  ').convert(s.tenancy?.toJson())));
                toast(context, 'Backup copied to clipboard');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Load demo data'),
              onTap: s.loadDemo,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
              title: Text('Start over', style: TextStyle(color: Colors.red.shade700)),
              subtitle: const Text('Deletes this tenancy from this device'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this tenancy?'),
                    content: const Text('This cannot be undone. Copy a backup first if you need one.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) s.reset();
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('DepositGuard 1.0 · Flutter · Web · Android · iOS · Windows',
              style: TextStyle(color: Theme.of(context).hintColor)),
        ),
      ],
    );
  }
}
