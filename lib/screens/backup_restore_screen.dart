// lib/screens/backup_restore_screen.dart
//
// Updates:
// - Export snackbar: "Backup saved" + Copy path action
// - Restore snackbar: "Restored successfully" + Copy path action
// - Friendlier errors (FormatException message shown)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _busy = false;

  void _snackWithCopy(String message, String path) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Copy path',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: path));
            if (!mounted) return;
            messenger.clearSnackBars();
            messenger.showSnackBar(
              const SnackBar(content: Text('Path copied.')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final ts = DateTime.now().toLocal().toIso8601String().replaceAll(':', '-');
      final path = await BackupService.exportJsonBackup(
        suggestedFileName: 'story_stalker_backup_$ts.json',
      );

      if (!mounted) return;

      if (path == null) {
        setState(() => _busy = false);
        return; // user cancelled
      }

      _snackWithCopy('Backup saved.', path);
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e is FormatException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $msg')),
      );
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will REPLACE your current library with the backup.\n\n'
          'Backups are not encrypted yet. Don’t store them somewhere public.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final path = await BackupService.restoreJsonBackup();

      if (!mounted) return;

      if (path == null) {
        setState(() => _busy = false);
        return; // user cancelled
      }

      _snackWithCopy('Restored successfully.', path);

      // Pop back and tell caller to refresh the home list.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e is FormatException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $msg')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Backups are a single JSON file. Restore is “replace only”.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              title: 'Export backup',
              subtitle: 'Save your library to a JSON file you choose.',
              icon: Icons.upload_outlined,
              enabled: !_busy,
              onTap: _export,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Restore backup',
              subtitle: 'Replace your current library from a JSON backup.',
              icon: Icons.download_outlined,
              enabled: !_busy,
              onTap: _restore,
              danger: true,
            ),

            if (_busy) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: danger ? scheme.error : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: danger ? scheme.error : scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
