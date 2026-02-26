// lib/screens/add_book_screen.dart
//
// v1 Add Book (Manual Entry)
// - Deliberate save (no autosave)
// - Writes to DB via BookRepository.addToVault()
// - Creative but simple UI: "Card form" + genre chips helper
//
// Assumes you have:
// - lib/data/repositories/book_repository.dart
// - lib/data/models/book_draft.dart

import 'package:flutter/material.dart';

import '../models/book_draft.dart';
import '../repositories/book_repository.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _genresCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int _status = 0; // 0=Want, 1=Reading, 2=Finished
  bool _saving = false;

  // A few quick-tap genre suggestions. Totally optional.
  final List<String> _genreSuggestions = const [
    'Fantasy',
    'Science Fiction',
    'Horror',
    'Mystery',
    'Thriller',
    'Romance',
    'Historical',
    'Nonfiction',
    'Biography',
    'Adventure',
    'Young Adult',
    'Comics',
  ];

  final Set<String> _selectedGenres = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _yearCtrl.dispose();
    _genresCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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

  void _syncGenresTextField() {
    final list = _selectedGenres.toList()..sort();
    _genresCtrl.text = list.join(', ');
  }

  void _toggleGenre(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
      }
      _syncGenresTextField();
    });
  }

  void _applyTypedGenres() {
    // Parse whatever user typed into the genres field into chips.
    final raw = _genresCtrl.text;
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _selectedGenres
        ..clear()
        ..addAll(parts.map(_normalizeGenre));
      _syncGenresTextField();
    });
  }

  String _normalizeGenre(String g) {
    // Minimal normalization for v1 (keeps things tidy).
    final trimmed = g.trim();
    if (trimmed.isEmpty) return trimmed;

    // Title-case-ish (simple): split by space and capitalize words.
    final words = trimmed.split(RegExp(r'\s+'));
    final tc = words.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
    return tc;
  }

  int? _parseYear(String? v) {
    if (v == null) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    final year = int.tryParse(t);
    if (year == null) return null;
    if (year < 0) return null;
    return year;
  }

  Future<void> _save() async {
    // Apply any typed genres into the set before validating/saving.
    _applyTypedGenres();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final draft = BookDraft(
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        year: _parseYear(_yearCtrl.text),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        genres: _selectedGenres.isEmpty? null: (_selectedGenres.toList()..sort()).join(', '),
      );

      final repo = BookRepository();
      await repo.addToVault(
        book: draft,
        initialStatus: _status,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // true = added
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add book: $e'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Book'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving' : 'Save'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // A little “vibe” header.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Drop in a book now. You can flesh out prompts and notes later.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Title (required)
                    TextFormField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. The Hobbit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Title is required';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Author + Year row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _authorCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Author',
                              hintText: 'e.g. J.R.R. Tolkien',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _yearCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              hintText: '1937',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null) return 'Numbers only';
                              if (parsed < 0) return 'Invalid year';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Status
                    DropdownButtonFormField<int>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Want')),
                        DropdownMenuItem(value: 1, child: Text('Reading')),
                        DropdownMenuItem(value: 2, child: Text('Finished')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _status = v);
                            },
                    ),

                    const SizedBox(height: 12),

                    // Genres
                    TextFormField(
                      controller: _genresCtrl,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Genres (comma-separated)',
                        hintText: 'Fantasy, Adventure',
                        border: OutlineInputBorder(),
                      ),
                      onEditingComplete: _applyTypedGenres,
                    ),

                    const SizedBox(height: 10),

                    // Genre chips
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _genreSuggestions.map((g) {
                          final selected = _selectedGenres.contains(g);
                          return FilterChip(
                            selected: selected,
                            label: Text(g),
                            onSelected: _saving ? null : (_) => _toggleGenre(g),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Short description',
                        hintText: 'Optional. A quick reminder of what this is about.',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Big Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save "${_statusLabel(_status)}"'),
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
}
