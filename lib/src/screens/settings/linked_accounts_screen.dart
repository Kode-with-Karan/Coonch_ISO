import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  static const int _maxLinks = 5;
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final linksRaw = auth.user?['social_links'];
    final links = linksRaw is List ? linksRaw.cast<dynamic>() : <dynamic>[];
    if (links.isEmpty) {
      _controllers.add(TextEditingController());
    } else {
      for (final link in links) {
        _controllers.add(TextEditingController(text: link?.toString() ?? ''));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() {
    if (_controllers.length >= _maxLinks) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeField(int index) {
    if (_controllers.length == 1) {
      _controllers[index].clear();
      return;
    }
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final links = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (links.length > _maxLinks) {
      notifications.showWarning('You can add up to $_maxLinks links.');
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final res = await auth.updateProfile({'social_links': links});
      Navigator.of(context).pop();
      if (res['success'] == 1) {
        await auth.refreshProfile();
        notifications.showSuccess('Linked accounts updated');
        Navigator.of(context).maybePop();
      } else {
        notifications.showError(NotificationService.formatMessage(
            res['message'] ?? 'Update failed'));
      }
    } catch (e) {
      Navigator.of(context).pop();
      notifications.showError(NotificationService.formatMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked accounts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add links to your social profiles. Up to 5 links.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[index],
                            decoration: InputDecoration(
                              hintText: 'https://',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeField(index),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed:
                      _controllers.length >= _maxLinks ? null : _addField,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add link'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
