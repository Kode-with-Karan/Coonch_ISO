import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../widgets/content_card.dart';
import '../widgets/network_avatar.dart';
import 'profile/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _recent = [];

  String _mode = 'content'; // 'content' or 'users'
  bool _loading = false;
  String? _error;
  List<dynamic> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) {
      // Rebuild so the clear button visibility tracks current input.
      setState(() {});
    }
    // debounce user typing
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = _controller.text.trim();
      if (q.isNotEmpty) _doSearch(q);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _loading = false;
      _error = null;
      _results = [];
    });
  }

  Future<void> _doSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      if (_mode == 'users') {
        final users = await api.searchUsers(query);
        if (!mounted) return;
        setState(() {
          _results = users;
          _loading = false;
        });
      } else {
        final contents =
            await api.getContents(queryParams: {'search_text': query});
        if (!mounted) return;

        // Apply a client-side safety filter so we only show items that
        // actually match the query text (robust against backends that
        // return unfiltered/full lists).
        final ql = query.toLowerCase();
        final filtered = contents.where((c) {
          try {
            final Map<String, dynamic> m = Map<String, dynamic>.from(c as Map);
            final caption =
                (m['caption'] ?? m['title'] ?? '').toString().toLowerCase();
            String username = '';
            if (m['user'] is Map) {
              username = (m['user']['username'] ?? m['user']['name'] ?? '')
                  .toString()
                  .toLowerCase();
            } else {
              username = (m['username'] ?? m['user_username'] ?? '')
                  .toString()
                  .toLowerCase();
            }
            return caption.contains(ql) || username.contains(ql);
          } catch (_) {
            return false;
          }
        }).toList();

        // Debug: show how many items were returned vs matched
        // ignore: avoid_print
        print(
            'SearchScreen: contents=${contents.length} matched=${filtered.length} for "$query"');

        setState(() {
          _results = filtered;
          _loading = false;
        });
      }

      // record recent
      // NOTE: do NOT record recent searches here. Recent entries are
      // recorded only when the user explicitly submits (presses Enter).
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed: ${e.toString()}';
        _loading = false;
      });
    }
  }

  /// Called when the user explicitly submits the search (presses Enter).
  /// Performs the search and records the query in recent searches.
  void _onSubmitted(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    _doSearch(query);
    if (!_recent.contains(query)) {
      setState(() => _recent.insert(0, query));
    }
  }

  Widget _modeToggle() {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('Content'),
          selected: _mode == 'content',
          onSelected: (v) {
            if (v) setState(() => _mode = 'content');
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Users'),
          selected: _mode == 'users',
          onSelected: (v) {
            if (v) setState(() => _mode = 'users');
          },
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_results.isEmpty) return const Center(child: Text('No results'));

    if (_mode == 'users') {
      return ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final u = _results[i] as Map;
          final id = (u['id'] ?? u['user_id'] ?? u['pk'])?.toString();
          final name =
              (u['name'] ?? u['username'] ?? u['email'])?.toString() ?? 'User';
          final avatar = (u['avatar'] ?? u['avatar_url'])?.toString();
          // Backend may return only `name` (no `username`). Display logic:
          // - If `username` exists: title = username, subtitle = name (if different)
          // - If no `username`: title = name, no subtitle (avoid duplicate)
          final rawUsername = u['username'];
          final username = rawUsername != null ? rawUsername.toString() : '';
          final displayNameRaw = u['name'];
          final displayName =
              displayNameRaw != null ? displayNameRaw.toString() : '';
          final firstNameRaw = u['first_name'] ?? u['firstName'];
          final lastNameRaw = u['last_name'] ?? u['lastName'];
          final firstName = firstNameRaw != null ? firstNameRaw.toString() : '';
          final lastName = lastNameRaw != null ? lastNameRaw.toString() : '';

          String titleText;
          String? subtitleText;

          if (username.isNotEmpty) {
            titleText = username;
            // prefer explicit first/last if provided
            final fullName = '$firstName $lastName'.trim();
            if (fullName.isNotEmpty) {
              subtitleText = fullName;
            } else if (displayName.isNotEmpty && displayName != username) {
              subtitleText = displayName;
            } else {
              subtitleText = null;
            }
          } else if (displayName.isNotEmpty) {
            // no username: use displayName as title. Avoid repeating
            titleText = displayName;
            subtitleText = null;
          } else {
            // Fallback to previous `name` variable or email
            titleText = name;
            subtitleText = null;
          }

          return ListTile(
            leading: NetworkAvatar(url: avatar, radius: 20),
            title: Text(titleText),
            subtitle: subtitleText != null ? Text(subtitleText) : null,
            onTap: id == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: id))),
          );
        },
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = Map<String, dynamic>.from(_results[i] as Map);
        return ContentCard(
          content: item,
          onUpdated: (fresh) {
            if (!mounted) return;
            setState(() => _results[i] = fresh);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _onSubmitted,
                  // Ensure the caret and entered text are vertically centered
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    hintText:
                        _mode == 'users' ? 'Search users' : 'Search content',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_controller.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _doSearch(_controller.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Align(
                    alignment: Alignment.centerLeft, child: _modeToggle()),
              ),
              if (_recent.isNotEmpty) ...[
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recent searches',
                        style: TextStyle(color: Colors.grey[600]))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _recent
                          .map((r) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ActionChip(
                                  label: Text(r,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  onPressed: () => _doSearch(r),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }
}
