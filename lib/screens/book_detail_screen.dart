// lib/screens/book_detail_screen.dart
//
// v1 Book Detail Screen
// - Separate screen (no expandable list tiles)
// - Edits vault-only fields: status, progress %, notes
// - Deliberate save via AppBar button
// - Optional: remove from vault (overflow menu)
//
// Expects:
// - BookRepository (updateVaultEntry, getVaultBookByUserBookId, removeFromVault)
// - VaultBook model

import 'package:flutter/material.dart';

import '../models/vault_book.dart';
import '../repositories/book_repository.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({
    super.key,
    required this.userBookId,
  });

  final int userBookId;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _notesCtrl = TextEditingController();

  late final BookRepository _repo;
  late Future<VaultBook?> _bookFuture;

  VaultBook? _book;

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  // Editable fields (staged until Save)
  int _status = 0;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _repo = BookRepository();
    _bookFuture = _repo.getVaultBookByUserBookId(widget.userBookId);
    _load();
    _notesCtrl.addListener(_markDirtyFromNotes);
  }

  @override
  void dispose() {
    _notesCtrl.removeListener(_markDirtyFromNotes);
    _notesCtrl.dispose();
    super.dispose();
  }

  void _markDirtyFromNotes() {
    if (!_loading) {
      // Don’t try to be clever: any notes edit flips dirty.
      if (!_dirty) setState(() => _dirty = true);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final loaded = await _bookFuture;
    if (!mounted) return;

    if (loaded == null) {
      setState(() {
        _book = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _book = loaded;

      _status = loaded.status;
      _progress = loaded.progressPercent.toDouble();

      _notesCtrl.text = loaded.notes ?? '';

      _dirty = false;
      _loading = false;
    });
  }

  String _statusLabel(int s) {
    switch (s) {
      case 1:
        return 'Reading';
      case 2:
        return 'Finished';
      case 0:
      default:
        return 'Want';
    }
  }

  String _subtitle(VaultBook b) {
    final parts = <String>[];
    final a = (b.author ?? '').trim();
    if (a.isNotEmpty) parts.add(a);
    if (b.year != null) parts.add(b.year.toString());
    return parts.join(' • ');
  }

  String _genresText(VaultBook b) {
    final g = (b.genres ?? '').trim();
    if (g.isEmpty) return 'No genres set';
    return g;
  }

  Future<void> _save() async {
    if (_book == null) return;
    if (!_dirty) return;

    setState(() => _saving = true);

    try {
      await _repo.updateVaultEntry(
        userBookId: widget.userBookId,
        status: _status,
        progressPercent: _progress.round(),
        notes: _notesCtrl.text,
      );

      if (!mounted) return;

      // Reload the full object so UI reflects DB truth.
      _bookFuture = _repo.getVaultBookByUserBookId(widget.userBookId);
      await _load();

      // Return signal to caller so list refreshes.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _confirmRemoveFromVault() async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from vault?'),
        content: const Text(
          'This removes the book from your vault. It can still exist as cached metadata later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.removeFromVault(widget.userBookId);
      if (!mounted) return;
      Navigator.of(context).pop(true); // tell list to refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_dirty || _saving) return true;

    final result = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. What do you want to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.cancel),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == _LeaveChoice.cancel || result == null) return false;
    if (result == _LeaveChoice.discard) return true;

    // Save then leave
    await _save();
    // If save pops the screen, this return value won’t matter. If it failed, stay.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Details'),
          actions: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: Text(
                    'Unsaved',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Save',
              onPressed: (_saving || !_dirty) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
            PopupMenuButton<_MenuAction>(
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.removeFromVault:
                    _confirmRemoveFromVault();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MenuAction.removeFromVault,
                  child: Text('Remove from vault'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_book == null)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Book not found (vault entry may have been removed).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : _buildContent(context, _book!),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, VaultBook book) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Header card
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle(book),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.local_offer_outlined, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _genresText(book),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Status + progress card
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _status,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Want')),
                  DropdownMenuItem(value: 1, child: Text('Reading')),
                  DropdownMenuItem(value: 2, child: Text('Finished')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _status = v;
                    _dirty = true;

                    // If user marks finished, we can *suggest* 100% by setting it, but still deliberate.
                    // This mirrors repo logic that forces 100% if Finished and no progress provided.
                    if (_status == 2 && _progress < 100) {
                      _progress = 100;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Progress',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_progress.round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: _progress.clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_progress.round()}%',
                onChanged: (v) {
                  setState(() {
                    _progress = v;
                    _dirty = true;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _status == 2 ? 'Finished' : _statusLabel(_status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Notes card
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  hintText: 'Jot down what you just read, thoughts, theories…',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: scheme.surface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Deliberate save: changes are not saved until you tap the save icon.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MenuAction {
  removeFromVault,
}

enum _LeaveChoice {
  cancel,
  discard,
  save,
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
