// lib/screens/book_list.dart
//
// Updates:
// 1) Search polish:
//    - Add clear "X" button (does NOT close search)
//    - Keep search icon at end of the bar, inclusive (closes search)
// 2) Counts:
//    - Show "Showing X of Y" (X=filtered list count, Y=total vault count)
// 3) Empty states:
//    - Specific messages for filters/search
//
// NOTE: This assumes you already have:
// - VaultBook model with userBookId/title/author/year/status/progressPercent
// - BookRepository.getVaultBooks({int? status, String? query})
// - SettingsScreen returns true after a restore (you already wired that)

import 'package:flutter/material.dart';

import '../models/vault_book.dart';
import '../repositories/book_repository.dart';
import '../state/app_settings_controller.dart';
import 'add_book_screen.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({
    super.key,
    required this.settings,
  });

  final AppSettingsController settings;

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  late final BookRepository _repo;

  late Future<List<VaultBook>> _booksFuture;
  late Future<int> _totalCountFuture;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  int? _statusFilter; // null=All, else 0/1/2

  @override
  void initState() {
    super.initState();
    _repo = BookRepository();
    _reloadAll();

    _searchCtrl.addListener(() {
      final next = _searchCtrl.text.trim();
      if (next == _query) return;
      setState(() {
        _query = next;
        _reloadBooksOnly();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _booksFuture = _repo.getVaultBooks(
      status: _statusFilter,
      query: _query.isEmpty ? null : _query,
    );
    _totalCountFuture = _repo
        .getVaultBooks(status: null, query: null)
        .then((list) => list.length);
  }

  void _reloadBooksOnly() {
    _booksFuture = _repo.getVaultBooks(
      status: _statusFilter,
      query: _query.isEmpty ? null : _query,
    );
  }

  Future<void> _refresh() async {
    setState(_reloadAll);
    await _booksFuture;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _query = '';
        _reloadBooksOnly();
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _clearSearch() {
    if (_searchCtrl.text.isEmpty) return;
    _searchCtrl.clear(); // listener will reload books
  }

  void _setStatusFilter(int? v) {
    setState(() {
      _statusFilter = v;
      _reloadBooksOnly();
    });
  }

  String _statusName(int? s) {
    switch (s) {
      case 0:
        return 'Want';
      case 1:
        return 'Reading';
      case 2:
        return 'Finished';
      default:
        return 'All';
    }
  }

  String _emptyStateText() {
    final hasQuery = _query.trim().isNotEmpty;
    final hasFilter = _statusFilter != null;

    if (hasQuery && hasFilter) {
      return 'No ${_statusName(_statusFilter)} books matching “$_query”.';
    }
    if (hasQuery) {
      return 'No results for “$_query”.';
    }
    if (hasFilter) {
      return 'No ${_statusName(_statusFilter)} books yet.';
    }
    return 'No books yet.\nTap + to add your first one.';
    }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _searching
                        ? _InlineSearchBar(
                            controller: _searchCtrl,
                            onClear: _clearSearch,
                            onClose: _toggleSearch,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Story Stalker',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Welcome back. Here are your books.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (!_searching) ...[
                    IconButton(
                      onPressed: _toggleSearch,
                      icon: const Icon(Icons.search),
                      tooltip: 'Search',
                      color: scheme.onSurfaceVariant,
                    ),
                    IconButton(
                      onPressed: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(settings: widget.settings),
                          ),
                        );
                        if (changed == true) {
                          await _refresh();
                        }
                      },
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),

            // Counts row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FutureBuilder<int>(
                future: _totalCountFuture,
                builder: (context, totalSnap) {
                  return FutureBuilder<List<VaultBook>>(
                    future: _booksFuture,
                    builder: (context, listSnap) {
                      final total = totalSnap.data;
                      final shown = listSnap.data?.length;

                      if (total == null || shown == null) {
                        return const SizedBox(height: 18);
                      }

                      final showingFiltered = (_statusFilter != null) || (_query.isNotEmpty);
                      final text = showingFiltered
                          ? 'Showing $shown of $total'
                          : '$total books';

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Status filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _StatusFilterRow(
                value: _statusFilter,
                onChanged: _setStatusFilter,
              ),
            ),

            // List (with pull-to-refresh)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<VaultBook>>(
                  future: _booksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Failed to load books.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: FilledButton.icon(
                              onPressed: () => setState(_reloadAll),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ),
                        ],
                      );
                    }

                    final books = snapshot.data ?? const <VaultBook>[];

                    if (books.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 80),
                          Text(
                            _emptyStateText(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _VaultBookTile(
                          book: book,
                          onTap: () async {
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => BookDetailScreen(userBookId: book.userBookId),
                              ),
                            );
                            if (changed == true) {
                              await _refresh();
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddBookScreen()),
          );
          if (added == true) {
            await _refresh();
          }
        },
        tooltip: 'Add Book',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InlineSearchBar extends StatelessWidget {
  const _InlineSearchBar({
    required this.controller,
    required this.onClear,
    required this.onClose,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search title or author…',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        isDense: true,
        filled: true,
        fillColor: scheme.surface,

        // Keep the SEARCH icon at the END of the bar (inclusive).
        // Add a clear "X" next to it.
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Clear',
              onPressed: controller.text.isEmpty ? null : onClear,
              icon: const Icon(Icons.close),
            ),
            IconButton(
              tooltip: 'Close search',
              onPressed: onClose,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({
    required this.value,
    required this.onChanged,
  });

  final int? value; // null=All
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        ChoiceChip(
          label: const Text('Want'),
          selected: value == 0,
          onSelected: (_) => onChanged(0),
        ),
        ChoiceChip(
          label: const Text('Reading'),
          selected: value == 1,
          onSelected: (_) => onChanged(1),
        ),
        ChoiceChip(
          label: const Text('Finished'),
          selected: value == 2,
          onSelected: (_) => onChanged(2),
        ),
      ],
    );
  }
}

class _VaultBookTile extends StatelessWidget {
  const _VaultBookTile({
    required this.book,
    required this.onTap,
  });

  final VaultBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final subtitleBits = <String>[];
    if ((book.author ?? '').trim().isNotEmpty) subtitleBits.add(book.author!.trim());
    if (book.year != null) subtitleBits.add(book.year.toString());
    final subtitle = subtitleBits.join(' • ');

    final progress = book.progressPercent.clamp(0, 100);

    String statusLabel;
    switch (book.status) {
      case 1:
        statusLabel = 'Reading';
        break;
      case 2:
        statusLabel = 'Finished';
        break;
      case 0:
      default:
        statusLabel = 'Want';
        break;
    }

    return Material(
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress / 100.0,
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$progress%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
