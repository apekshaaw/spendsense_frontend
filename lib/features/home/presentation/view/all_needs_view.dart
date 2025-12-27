import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';

class AllNeedsView extends StatefulWidget {
  const AllNeedsView({super.key});

  @override
  State<AllNeedsView> createState() => _AllNeedsViewState();
}

class _AllNeedsViewState extends State<AllNeedsView> {
  bool _loading = true;
  List<Map<String, dynamic>> _needs = [];

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('authToken') ??
        prefs.getString('accessToken');
  }

  @override
  void initState() {
    super.initState();
    _loadNeeds();
  }

  Future<void> _loadNeeds() async {
    setState(() => _loading = true);

    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) return;

      final res = await http.get(
        Uri.parse(ApiEndpoints.needs),
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

        setState(() => _needs = list);
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Failed to load needs')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading needs: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteNeed(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete need?'),
        content: const Text('This will permanently delete this need.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) return;

      final res = await http.delete(
        Uri.parse('${ApiEndpoints.needs}/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        await _loadNeeds();
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? 'Failed to delete need')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        title: const Text('All Needs'),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _needs.isEmpty
              ? const Center(child: Text('No needs yet. Add one first.'))
              : RefreshIndicator(
                  onRefresh: _loadNeeds,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _needs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = _needs[index];
                      final id = (n['_id'] ?? '').toString();
                      final name = (n['name'] ?? '').toString();
                      final price = ((n['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);

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
                                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('\$$price', style: const TextStyle(color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteNeed(id),
                              icon: const Icon(Icons.delete_outline),
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
