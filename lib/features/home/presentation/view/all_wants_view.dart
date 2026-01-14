import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';

class AllWantsView extends StatefulWidget {
  const AllWantsView({super.key});

  @override
  State<AllWantsView> createState() => _AllWantsViewState();
}

class _AllWantsViewState extends State<AllWantsView> {
  bool _loading = true;
  List<Map<String, dynamic>> _wants = [];

  // ✅ 10 seconds option for testing + normal minute options
  final List<_ReminderOption> _options = const [
    _ReminderOption(label: '10 seconds (test)', seconds: 10),
    _ReminderOption(label: '1 hour', minutes: 60),
    _ReminderOption(label: '6 hours', minutes: 360),
    _ReminderOption(label: '24 hours', minutes: 1440),
    _ReminderOption(label: '3 days', minutes: 4320),
    _ReminderOption(label: '1 week', minutes: 10080),
  ];

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('authToken') ??
        prefs.getString('accessToken');
  }

  @override
  void initState() {
    super.initState();
    _loadWants();
  }

  Future<void> _loadWants() async {
    setState(() => _loading = true);

    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) return;

      final res = await http.get(
        Uri.parse(ApiEndpoints.wants),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        setState(() => _wants = list);
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Failed to load wants')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading wants: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) return;

      final res = await http.patch(
        Uri.parse('${ApiEndpoints.wants}/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        await _loadWants();
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Failed to update status')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteWant(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete want?'),
        content: const Text('This will permanently delete this want.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) return;

      final res = await http.delete(
        Uri.parse('${ApiEndpoints.wants}/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        await _loadWants();
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Failed to delete want')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openEditWant(Map<String, dynamic> want) async {
    final id = (want['_id'] ?? '').toString();

    final nameCtrl =
        TextEditingController(text: (want['name'] ?? '').toString());
    final priceCtrl = TextEditingController(
      text: ((want['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    final notesCtrl =
        TextEditingController(text: (want['notes'] ?? '').toString());

    _ReminderOption? selectedOption; // ✅ supports seconds or minutes

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit Want'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = num.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Enter valid price';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reminder (optional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: selectedOption == null,
                        onSelected: (_) => setLocal(() => selectedOption = null),
                      ),
                      ..._options.map(
                        (opt) => ChoiceChip(
                          label: Text(opt.label),
                          selected: selectedOption == opt,
                          onSelected: (_) =>
                              setLocal(() => selectedOption = opt),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;

                      setLocal(() => saving = true);

                      try {
                        final token = await _getAuthToken();
                        if (token == null || token.isEmpty) return;

                        final body = <String, dynamic>{
                          'name': nameCtrl.text.trim(),
                          'price': double.parse(priceCtrl.text.trim()),
                          'notes': notesCtrl.text.trim(),
                        };

                        // ✅ If None -> clear remindAt
                        if (selectedOption == null) {
                          body['remindAt'] = null;
                        } else {
                          // ✅ If selected seconds
                          if (selectedOption!.seconds != null) {
                            body['remindAfterSeconds'] = selectedOption!.seconds;
                          }
                          // ✅ If selected minutes
                          if (selectedOption!.minutes != null) {
                            body['remindAfterMinutes'] = selectedOption!.minutes;
                          }
                        }

                        final res = await http.patch(
                          Uri.parse('${ApiEndpoints.wants}/$id'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode(body),
                        );

                        if (!mounted) return;

                        if (res.statusCode == 200) {
                          Navigator.pop(ctx);
                          await _loadWants();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Want updated')),
                          );
                        } else {
                          final resp = jsonDecode(res.body);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(resp['message'] ?? 'Update failed')),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setLocal(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    notesCtrl.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'skipped':
        return Colors.green;
      case 'purchased':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,      appBar: AppBar(
        title: const Text('All Wants'),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wants.isEmpty
              ? const Center(child: Text('No wants yet. Add one first.'))
              : RefreshIndicator(
                  onRefresh: _loadWants,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _wants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final w = _wants[index];
                      final id = (w['_id'] ?? '').toString();
                      final name = (w['name'] ?? '').toString();
                      final price =
                          ((w['price'] as num?)?.toDouble() ?? 0)
                              .toStringAsFixed(0);
                      final status = (w['status'] ?? 'pending').toString();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.authCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs$price',
                                    style: const TextStyle(
                                        color: AppColors.textGrey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(status),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openEditWant(w);
                                } else if (value == 'delete') {
                                  _deleteWant(id);
                                } else {
                                  _updateStatus(id, value);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                    value: 'pending', child: Text('Mark Pending')),
                                PopupMenuItem(
                                    value: 'skipped', child: Text('Mark Skipped')),
                                PopupMenuItem(
                                    value: 'purchased',
                                    child: Text('Mark Purchased')),
                                PopupMenuDivider(),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ReminderOption {
  final String label;
  final int? minutes;
  final int? seconds;

  const _ReminderOption({
    required this.label,
    this.minutes,
    this.seconds,
  }) : assert(
          (minutes != null) ^ (seconds != null),
          'Provide either minutes OR seconds (not both).',
        );
}
