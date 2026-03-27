import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/network_avatar.dart';
import '../widgets/subscription_dialog.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/content/content_detail_screen.dart';
import '../utils/content_access.dart';
import 'audio_player_widget.dart';

/// Reusable content card used across feed and profile screens.
/// Accepts a `content` map (as returned by the backend) and an optional
/// `onUpdated` callback which is called with the authoritative refreshed
/// content map after like/comment operations.
class ContentCard extends StatefulWidget {
  final Map<String, dynamic> content;
  final void Function(Map<String, dynamic>)? onUpdated;

  const ContentCard({super.key, required this.content, this.onUpdated});

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  late String _likesDisplay;
  late String _commentsDisplay;
  late bool _isLiked;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    _likesDisplay = _safeLikes(content);
    _commentsDisplay = _safeComments(content);
    try {
      _isLiked = (content['is_liked_by_me'] == true);
    } catch (_) {
      _isLiked = false;
    }
  }

  Future<void> _openSubscriptionPlans() async {
    if (!mounted) return;
    await showSubscriptionRequiredDialog(context, content: widget.content);
  }

  Future<void> _showEditDialog(String contentId) async {
    final initialCaption = _safeText(widget.content);
    String? selectedTopic;
    try {
      final t = widget.content['topic'];
      if (t != null) selectedTopic = t.toString();
    } catch (_) {}

    final api = Provider.of<ApiService>(context, listen: false);
    List<dynamic> categories = [];
    try {
      categories = await api.getCategories();
    } catch (_) {
      categories = [];
    }

    int? selectedCategoryId;
    try {
      final c = widget.content['category'];
      if (c is Map && c['id'] != null) {
        selectedCategoryId = int.tryParse(c['id'].toString());
      } else if (widget.content['category_id'] != null) {
        selectedCategoryId =
            int.tryParse(widget.content['category_id'].toString());
      } else if (widget.content['category'] is int) {
        selectedCategoryId = widget.content['category'] as int;
      }
    } catch (_) {
      selectedCategoryId = null;
    }

    final TextEditingController controller =
        TextEditingController(text: initialCaption);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit post'),
        content: StatefulBuilder(builder: (context, setState) {
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Caption'),
                maxLines: null,
              ),
              const SizedBox(height: 8),
              if (categories.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map<DropdownMenuItem<int?>>((c) {
                    final id = c is Map && c['id'] != null
                        ? (int.tryParse(c['id'].toString()))
                        : null;
                    final name = c is Map && c['name'] != null
                        ? c['name'].toString()
                        : c.toString();
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedCategoryId = v),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text('Entertainment'),
                  selected: selectedTopic == 'entertainment',
                  onSelected: (s) => setState(() {
                    selectedTopic = s ? 'entertainment' : null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Education'),
                  selected: selectedTopic == 'education',
                  onSelected: (s) => setState(() {
                    selectedTopic = s ? 'education' : null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Infotainment'),
                  selected: selectedTopic == 'infotainment',
                  onSelected: (s) => setState(() {
                    selectedTopic = s ? 'infotainment' : null;
                  }),
                ),
              ])
            ]),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () async {
                final notifications =
                    Provider.of<NotificationService>(context, listen: false);
                final fields = <String, String>{
                  'caption': controller.text.trim()
                };
                if (selectedTopic != null) fields['topic'] = selectedTopic!;
                if (selectedCategoryId != null) {
                  fields['category'] = selectedCategoryId.toString();
                }
                Navigator.of(d).pop();
                try {
                  await api.updateContent(contentId, fields);
                  try {
                    final fresh = await api.getContentById(contentId);
                    if (!mounted) return;
                    widget.onUpdated?.call(fresh);
                    notifications.showSuccess('Post updated');
                    setState(() {
                      _likesDisplay = _safeLikes(fresh);
                      _commentsDisplay = _safeComments(fresh);
                      _isLiked = (fresh['is_liked_by_me'] == true);
                    });
                  } catch (_) {
                    notifications.showInfo('Updated (no refresh)');
                  }
                } catch (e) {
                  final msg = e is ApiException
                      ? 'Update failed (${e.code}): ${e.body}'
                      : 'Update failed: ${e.toString()}';
                  notifications
                      .showError(NotificationService.formatMessage(msg));
                }
              },
              child: const Text('Save'))
        ],
      ),
    );
  }

  bool _isOwner() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final cur = auth.user;
      if (cur == null) return false;
      String? uid;
      if (cur['id'] != null) uid = cur['id'].toString();
      if (uid == null && cur['user_id'] != null) {
        uid = cur['user_id'].toString();
      }
      final owner = _safeUserId(widget.content);
      if (uid == null || owner == null) return false;
      return uid == owner;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showReportDialog(String contentId) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);

    String selectedReason = 'Spam';
    final TextEditingController detailsController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Report post'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Why are you reporting this post?'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                      DropdownMenuItem(
                          value: 'Harassment', child: Text('Harassment')),
                      DropdownMenuItem(
                          value: 'Hate speech', child: Text('Hate speech')),
                      DropdownMenuItem(
                          value: 'Violence', child: Text('Violence')),
                      DropdownMenuItem(value: 'Nudity', child: Text('Nudity')),
                      DropdownMenuItem(
                          value: 'Misinformation',
                          child: Text('Misinformation')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedReason = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Additional details (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      await api.reportContent(
        contentId,
        reason: selectedReason,
        details: detailsController.text.trim(),
      );
      notifications.showSuccess('Thanks. Your report has been submitted.');
    } catch (e) {
      final msg = e is ApiException
          ? 'Report failed (${e.code}): ${e.body}'
          : 'Report failed: ${e.toString()}';
      notifications.showError(NotificationService.formatMessage(msg));
    }
  }

  Future<void> _onMorePressed() async {
    final contentId = widget.content['id']?.toString();
    if (contentId == null) return;
    final api = Provider.of<ApiService>(context, listen: false);

    if (_isOwner()) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(c).pop();
                _showEditDialog(contentId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(c).pop();
                final confirm = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                          title: const Text('Confirm delete'),
                          content: const Text(
                              'Are you sure you want to delete this post?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(d).pop(false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.of(d).pop(true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ));
                if (confirm != true) return;
                final notifications =
                    Provider.of<NotificationService>(context, listen: false);
                try {
                  await api.deleteContent(contentId);
                  setState(() => _deleted = true);
                  notifications.showSuccess('Post deleted successfully');
                  try {
                    widget.onUpdated?.call({'deleted': true, 'id': contentId});
                  } catch (_) {}
                } catch (e) {
                  final msg = e is ApiException
                      ? 'Delete failed (${e.code}): ${e.body}'
                      : 'Delete failed: ${e.toString()}';
                  notifications
                      .showError(NotificationService.formatMessage(msg));
                }
              },
            ),
          ]),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
            child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Report'),
            onTap: () {
              Navigator.of(c).pop();
              _showReportDialog(contentId);
            },
          )
        ])),
      );
    }
  }

  int? _parseInt(String s) {
    try {
      final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.isEmpty) return null;
      return int.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleLike() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final contentId = widget.content['id']?.toString();
    if (contentId == null) return;

    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final current = _parseInt(_likesDisplay);
    setState(() {
      _isLiked = !_isLiked;
      if (current != null) {
        _likesDisplay = (_isLiked ? (current + 1) : (current - 1)).toString();
      }
    });

    try {
      await api.likeUnlikeContent(contentId);
      // Refresh authoritative values
      try {
        final fresh = await api.getContentById(contentId);
        if (!mounted) return;
        setState(() {
          _isLiked = (fresh['is_liked_by_me'] == true);
          if (fresh['likes_count'] != null) {
            _likesDisplay = fresh['likes_count'].toString();
          } else if (fresh['likes'] != null) {
            _likesDisplay = fresh['likes'].toString();
          }
        });
        widget.onUpdated?.call(fresh);
      } catch (_) {}
    } catch (e) {
      // revert on error
      final current2 = _parseInt(_likesDisplay);
      setState(() {
        _isLiked = !_isLiked;
        if (current2 != null) {
          _likesDisplay =
              (_isLiked ? (current2 + 1) : (current2 - 1)).toString();
        }
      });
      // Provide richer error info for debugging
      final msg = e is ApiException
          ? 'Like failed (${e.code}): ${e.body}'
          : 'Like failed: ${e.toString()}';
      debugPrint('Like error for content $contentId: ${e.toString()}');
      if (e is ApiException && e.code == 404) {
        // Content not found on server anymore; hide this card
        setState(() => _deleted = true);
        if (mounted) {
          notifications.showInfo('Content not found (removed)');
        }
        return;
      }
      if (mounted) {
        notifications.showError(NotificationService.formatMessage(msg));
      }
    }
  }

  Future<void> _showComments() async {
    if (isLockedContent(widget.content)) {
      await _openSubscriptionPlans();
      return;
    }

    final api = Provider.of<ApiService>(context, listen: false);
    final contentId = widget.content['id']?.toString();
    if (contentId == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String? currentUserId;
    try {
      final cur = auth.user;
      if (cur != null) {
        currentUserId = (cur['id'] ?? cur['user_id'] ?? cur['pk'])?.toString();
      }
    } catch (_) {
      currentUserId = null;
    }

    Future<void> refreshParentCommentCount() async {
      try {
        final fresh = await api.getContentById(contentId);
        if (!mounted) return;
        setState(() {
          if (fresh['comments_count'] != null) {
            _commentsDisplay = fresh['comments_count'].toString();
          } else if (fresh['comments'] != null) {
            _commentsDisplay = (fresh['comments'] is List
                ? (fresh['comments'] as List).length.toString()
                : fresh['comments'].toString());
          }
        });
        widget.onUpdated?.call(fresh);
      } catch (_) {}
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final TextEditingController controller = TextEditingController();

        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Comments',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close))
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: api.getContentById(contentId),
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                              child: Text(
                                  'Failed to load comments: ${snap.error}'));
                        }
                        final data = snap.data ?? {};
                        final comments = data['comments'] is List
                            ? data['comments'] as List<dynamic>
                            : <dynamic>[];

                        if (comments.isEmpty) {
                          return const Center(child: Text('No comments yet'));
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemBuilder: (context, i) {
                            final cmt = comments[i] as Map<dynamic, dynamic>;
                            final user = cmt['user'];
                            final uname = (user is Map &&
                                    (user['username'] != null ||
                                        user['name'] != null))
                                ? (user['username'] ?? user['name']).toString()
                                : 'Unknown';
                            final avatar = (user is Map &&
                                    (user['avatar'] != null ||
                                        user['avatar_url'] != null))
                                ? (user['avatar'] ?? user['avatar_url'])
                                    .toString()
                                : null;
                            final text = cmt['comment_text']?.toString() ?? '';

                            // Try to extract user id for navigation from the comment's user
                            String? commentUserId;
                            if (user is Map) {
                              commentUserId =
                                  (user['id'] ?? user['user_id'] ?? user['pk'])
                                      ?.toString();
                            }
                            final commentId = cmt['id']?.toString();
                            final isMyComment = currentUserId != null &&
                                commentUserId != null &&
                                currentUserId == commentUserId;

                            return ListTile(
                              leading: avatar != null
                                  ? GestureDetector(
                                      onTap: () {
                                        if (commentUserId != null) {
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) => ProfileScreen(
                                                      userId: commentUserId)));
                                        }
                                      },
                                      child: NetworkAvatar(
                                          url: avatar, radius: 18))
                                  : const CircleAvatar(
                                      radius: 18, child: Icon(Icons.person)),
                              title: GestureDetector(
                                onTap: () {
                                  if (commentUserId != null) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                                userId: commentUserId)));
                                  }
                                },
                                child: Text(uname,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              subtitle: Text(text),
                              trailing: (isMyComment && commentId != null)
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          final editController =
                                              TextEditingController(text: text);
                                          final updatedText =
                                              await showDialog<String>(
                                            context: context,
                                            builder: (d) => AlertDialog(
                                              title: const Text('Edit comment'),
                                              content: TextField(
                                                controller: editController,
                                                maxLines: null,
                                                decoration:
                                                    const InputDecoration(
                                                  hintText:
                                                      'Update your comment...',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(d).pop(),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(d).pop(
                                                          editController.text
                                                              .trim()),
                                                  child: const Text('Save'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (updatedText == null ||
                                              updatedText.isEmpty ||
                                              updatedText == text) {
                                            return;
                                          }

                                          try {
                                            await api.updateComment(contentId,
                                                commentId, updatedText);
                                            setModalState(() {});
                                            await refreshParentCommentCount();
                                          } catch (e) {
                                            final msg = e is ApiException
                                                ? 'Edit failed (${e.code}): ${e.body}'
                                                : 'Edit failed: ${e.toString()}';
                                            if (mounted) {
                                              Provider.of<NotificationService>(
                                                      context,
                                                      listen: false)
                                                  .showError(NotificationService
                                                      .formatMessage(msg));
                                            }
                                          }
                                          return;
                                        }

                                        if (value == 'delete') {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (d) => AlertDialog(
                                              title:
                                                  const Text('Delete comment'),
                                              content: const Text(
                                                  'Are you sure you want to delete this comment?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(d)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(d).pop(true),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm != true) return;

                                          try {
                                            await api.deleteComment(
                                                contentId, commentId);
                                            setModalState(() {});
                                            await refreshParentCommentCount();
                                          } catch (e) {
                                            final msg = e is ApiException
                                                ? 'Delete failed (${e.code}): ${e.body}'
                                                : 'Delete failed: ${e.toString()}';
                                            if (mounted) {
                                              Provider.of<NotificationService>(
                                                      context,
                                                      listen: false)
                                                  .showError(NotificationService
                                                      .formatMessage(msg));
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(),
                          itemCount: comments.length,
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                hintText: 'Write a comment...',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Track sending state inside the modal so the Send button
                          // can be disabled while a comment is being posted.
                          Builder(builder: (ctx) {
                            bool sending = false;
                            return StatefulBuilder(builder: (c2, setSending) {
                              return ElevatedButton(
                                onPressed: sending
                                    ? null
                                    : () async {
                                        final text = controller.text.trim();
                                        if (text.isEmpty) return;
                                        setSending(() => sending = true);
                                        try {
                                          await api.commentContent(
                                              contentId, text);
                                          // refresh modal
                                          controller.clear();
                                          setModalState(() {});
                                          // update parent comment count
                                          await refreshParentCommentCount();
                                        } catch (e) {
                                          final msg = e is ApiException
                                              ? 'Comment failed (${e.code}): ${e.body}'
                                              : 'Comment failed: ${e.toString()}';
                                          Provider.of<NotificationService>(
                                                  context,
                                                  listen: false)
                                              .showError(NotificationService
                                                  .formatMessage(msg));
                                        } finally {
                                          setSending(() => sending = false);
                                        }
                                      },
                                child: sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Post'),
                              );
                            });
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final content = widget.content;
    final name = _safeUserName(content);
    final image = _safeImage(content);
    final text = _safeText(content);
    final lockedContent = isLockedContent(content);
    final screenWidth = MediaQuery.of(context).size.width;
    final useWideLayout = kIsWeb || screenWidth >= 1000;
    final maxCardWidth = useWideLayout ? 860.0 : double.infinity;
    final mediaHeight = useWideLayout ? 240.0 : 200.0;
    final lockedPreviewHeight = useWideLayout ? 170.0 : 180.0;

    return Padding(
        padding: EdgeInsets.symmetric(
            horizontal: useWideLayout ? 20 : 12, vertical: 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (lockedContent) {
                  await _openSubscriptionPlans();
                  return;
                }

                // Open content detail when tapping the card
                final contentId = widget.content['id']?.toString();
                final navigator = Navigator.of(context);
                final result = await navigator.push(MaterialPageRoute(
                    builder: (_) => ContentDetailScreen(
                          contentId: contentId,
                          initialContent: widget.content,
                        )));
                if (result is Map<String, dynamic>) {
                  widget.onUpdated?.call(result);
                } else {
                  try {
                    final api = Provider.of<ApiService>(context, listen: false);
                    if (contentId != null) {
                      final fresh = await api.getContentById(contentId);
                      widget.onUpdated?.call(fresh);
                    }
                  } catch (_) {}
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final uid = _safeUserId(content);
                              if (uid != null) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileScreen(userId: uid)));
                              }
                            },
                            child: NetworkAvatar(
                                url: _safeAvatar(content), radius: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final uid = _safeUserId(content);
                                if (uid != null) {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(userId: uid)));
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                              onPressed: _onMorePressed,
                              icon: const Icon(Icons.more_horiz,
                                  color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (lockedContent)
                      _buildLockedPreview(content, height: lockedPreviewHeight)
                    else if (content['type'] == 'audio')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: AudioPlayerWidget(
                            url: (content['file_url'] ?? content['audio_url'])
                                ?.toString()),
                      )
                    else if (image != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12)),
                        child: Image.network(
                          image,
                          height: mediaHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: mediaHeight,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Caption / text (show preview and 'View more' when truncated)
                            if (lockedContent) ...[
                              _buildLockedMessage(content),
                              const SizedBox(height: 8),
                            ] else if (text.isNotEmpty) ...[
                              _CaptionPreview(
                                text: text,
                                onViewMore: () async {
                                  final contentId =
                                      widget.content['id']?.toString();
                                  if (contentId == null) return;
                                  final navigator = Navigator.of(context);
                                  final result =
                                      await navigator.push(MaterialPageRoute(
                                          builder: (_) => ContentDetailScreen(
                                                contentId: contentId,
                                                initialContent: widget.content,
                                              )));
                                  if (result is Map<String, dynamic>) {
                                    widget.onUpdated?.call(result);
                                  } else {
                                    try {
                                      final api = Provider.of<ApiService>(
                                          context,
                                          listen: false);
                                      final fresh =
                                          await api.getContentById(contentId);
                                      widget.onUpdated?.call(fresh);
                                    } catch (_) {}
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Actions: likes and comments are displayed below the text/media
                            if (lockedContent)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _openSubscriptionPlans,
                                  icon: const Icon(Icons.lock_open),
                                  label: Text(lockedActionLabel(content)),
                                ),
                              )
                            else
                              Row(children: [
                                IconButton(
                                    onPressed: _toggleLike,
                                    icon: Icon(
                                        _isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: Colors.red)),
                                const SizedBox(width: 6),
                                Text(_likesDisplay,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                IconButton(
                                    onPressed: _showComments,
                                    icon:
                                        const Icon(Icons.chat_bubble_outline)),
                                const SizedBox(width: 6),
                                Text(_commentsDisplay,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ]),
                          ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  // Helper functions
  String _safeUserName(dynamic content) {
    try {
      if (content is Map && content['user'] != null) {
        final u = content['user'];
        if (u is Map) {
          if (u['username'] != null) return u['username'].toString();
          if (u['name'] != null) return u['name'].toString();
        }
        if (u is String) return u;
      }
    } catch (_) {}
    return 'Unknown';
  }

  String? _safeImage(dynamic content) {
    try {
      if (content is Map) {
        if (content['thumbnail_url'] != null) {
          return content['thumbnail_url'] as String;
        }
        if (content['file_url'] != null) return content['file_url'] as String;
      }
    } catch (_) {}
    return null;
  }

  String _safeText(dynamic content) {
    try {
      if (content is Map && content['caption'] != null) {
        return content['caption'].toString();
      }
    } catch (_) {}
    return '';
  }

  String _safeLikes(dynamic content) {
    try {
      if (content is Map && content['likes_count'] != null) {
        return content['likes_count'].toString();
      }
      if (content is Map && content['likes'] != null) {
        return content['likes'].toString();
      }
    } catch (_) {}
    return '0';
  }

  Widget _buildLockedPreview(Map<String, dynamic> content,
      {double height = 180}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 44, color: Color(0xFF1565C0)),
          const SizedBox(height: 12),
          Text(
            '${requiredPlanTopicLabel(content)} content is locked',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              contentAccessMessage(content),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedMessage(Map<String, dynamic> content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              contentAccessMessage(content),
              style: TextStyle(
                color: Colors.orange.shade900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeComments(dynamic content) {
    try {
      if (content is Map && content['comments_count'] != null) {
        return content['comments_count'].toString();
      }
      if (content is Map && content['comments'] != null) {
        return (content['comments'] is List
            ? (content['comments'] as List).length.toString()
            : content['comments'].toString());
      }
    } catch (_) {}
    return '0';
  }

  String? _safeAvatar(dynamic content) {
    try {
      if (content is Map) {
        if (content['user'] is Map) {
          final u = content['user'] as Map;
          if (u['avatar'] != null) return u['avatar'] as String;
          if (u['avatar_url'] != null) return u['avatar_url'] as String;
        }
        if (content['avatar'] != null) return content['avatar'] as String;
        if (content['avatar_url'] != null) {
          return content['avatar_url'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Try to extract the user id from the content map.
  String? _safeUserId(dynamic content) {
    try {
      if (content is Map) {
        if (content['user'] is Map) {
          final u = content['user'] as Map;
          if (u['id'] != null) return u['id'].toString();
          if (u['user_id'] != null) return u['user_id'].toString();
          if (u['pk'] != null) return u['pk'].toString();
        }
        if (content['user_id'] != null) return content['user_id'].toString();
        if (content['user'] is String) return content['user'] as String;
      }
    } catch (_) {}
    return null;
  }
}

/// Small helper that shows a truncated caption with an optional
/// "View more" action when text exceeds [maxPreviewChars].
class _CaptionPreview extends StatelessWidget {
  final String text;
  final int maxPreviewChars;
  final VoidCallback onViewMore;

  const _CaptionPreview(
      {Key? key,
      required this.text,
      required this.onViewMore,
      int? maxPreviewChars})
      : maxPreviewChars = maxPreviewChars ?? 140,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final needsTruncate = trimmed.length > maxPreviewChars;
    final preview = needsTruncate
        ? '${trimmed.substring(0, maxPreviewChars).trim()}...'
        : trimmed;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(preview, style: const TextStyle(fontSize: 14, height: 1.4)),
      if (needsTruncate)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: onViewMore,
            child: const Text('View more',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ),
    ]);
  }
}
