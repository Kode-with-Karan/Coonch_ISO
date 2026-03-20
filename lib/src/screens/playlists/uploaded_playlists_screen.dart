import 'package:flutter/material.dart';

import '../../services/playlist_service.dart';
import 'create_playlist_screen.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  String _filter = 'All';
  bool _loading = false;
  List<Map<String, dynamic>> _playlists = [];

  List<Map<String, dynamic>> get _filtered => _filter == 'All'
      ? _playlists
      : _playlists
          .where((p) =>
              (p['type'] ?? '').toString().toLowerCase() ==
              _filter.toLowerCase())
          .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await PlaylistService.loadPlaylists();
    if (mounted) {
      setState(() {
        _playlists = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Playlists'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePlaylistScreen()),
          );
          if (mounted) _load();
        },
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    _typeChip('All'),
                    const SizedBox(width: 10),
                    _typeChip('Video'),
                    const SizedBox(width: 10),
                    _typeChip('Audio'),
                    const SizedBox(width: 10),
                    _typeChip('Text'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('No playlists yet'),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const CreatePlaylistScreen()),
                                    );
                                    if (mounted) _load();
                                  },
                                  child: const Text('Create playlist'),
                                )
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            itemBuilder: (ctx, i) {
                              final item = _filtered[i];
                              final cover = (item['cover'] ?? '')
                                      .toString()
                                      .isNotEmpty
                                  ? item['cover'] as String
                                  : (item['posts'] is List &&
                                          (item['posts'] as List).isNotEmpty
                                      ? (((item['posts'] as List)[0]
                                                  as Map)['thumbnail_url'] ??
                                              ((item['posts'] as List)[0]
                                                  as Map)['file_url'] ??
                                              '')
                                          .toString()
                                      : '');
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: cover.isNotEmpty
                                            ? Image.network(
                                                cover,
                                                height: 160,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  height: 160,
                                                  width: double.infinity,
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey),
                                                ),
                                              )
                                            : Container(
                                                height: 160,
                                                width: double.infinity,
                                                color: Colors.grey[100],
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                    Icons.playlist_play,
                                                    color: Colors.grey,
                                                    size: 48),
                                              ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                                (item['title'] ?? '')
                                                    .toString(),
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.chevron_right),
                                            onPressed: () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PlaylistDetailScreen(
                                                          playlist: item),
                                                ),
                                              );
                                              if (mounted) _load();
                                            },
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        (item['description'] ?? '').toString(),
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text('See more',
                                          style: TextStyle(
                                              color: Colors.lightBlue[700])),
                                    ],
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemCount: _filtered.length,
                          ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label) {
    final selected = _filter == label;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _filter = label),
      label: Text(label,
          style: TextStyle(color: selected ? Colors.white : Colors.grey[800])),
      selectedColor: Colors.lightBlue,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selected ? Colors.transparent : Colors.grey.shade200)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
}
