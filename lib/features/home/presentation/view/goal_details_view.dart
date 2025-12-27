// lib/features/home/presentation/view/goal_details_view.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import 'edit_goal_view.dart';

/// Same helper as in AddGoalView – you can move this to a shared file later.
Future<String?> _getAuthToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token') ??
      prefs.getString('authToken') ??
      prefs.getString('accessToken');
}

class GoalDetailsView extends StatefulWidget {
  final String goalId; // not used by API now, but kept for future
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? notes;

  const GoalDetailsView({
    super.key,
    required this.goalId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.notes,
  });

  @override
  State<GoalDetailsView> createState() => _GoalDetailsViewState();
}

class _GoalDetailsViewState extends State<GoalDetailsView> {
  int _amount = 0;
  bool _isSaving = false;
  bool _isLoading = false;

  late String _name;
  late double _targetAmount;
  late double _currentAmount;
  String? _notes;

  List<dynamic> _entries = [];

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _targetAmount = widget.targetAmount;
    _currentAmount = widget.currentAmount;
    _notes = widget.notes;
    _fetchGoal(); // get latest data + history from backend
  }

  double get _progress {
    if (_targetAmount <= 0) return 0;
    final p = _currentAmount / _targetAmount;
    return p.clamp(0, 1);
  }

  double get _amountAway =>
      (_targetAmount - _currentAmount).clamp(0, double.infinity);

  Future<void> _fetchGoal() async {
    setState(() => _isLoading = true);

    try {
      final token = await _getAuthToken();

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authorized, no token. Please log in again.'),
          ),
        );
        return;
      }

      final uri = Uri.parse('${ApiEndpoints.goals}/me');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _name = data['name']?.toString() ?? _name;
          _targetAmount =
              (data['targetAmount'] as num?)?.toDouble() ?? _targetAmount;
          _currentAmount =
              (data['currentAmount'] as num?)?.toDouble() ?? _currentAmount;
          _notes = data['notes']?.toString();
          _entries = (data['entries'] as List?) ?? [];
        });
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No goal set yet.')),
        );
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message']?.toString() ?? 'Failed to load goal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading goal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEntry() async {
    if (_amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set an amount before saving entry.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = await _getAuthToken();

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authorized, no token. Please log in again.'),
          ),
        );
        return;
      }

      // PATCH /api/goals/me/progress
      final uri = Uri.parse('${ApiEndpoints.goals}/me/progress');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode({
          'amount': _amount,
          'type': 'saved', // this screen logs saved entries
          // 'note': 'Manual entry', // optional – you can add a note field later
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentAmount =
              (data['currentAmount'] as num?)?.toDouble() ?? _currentAmount;
          _entries = (data['entries'] as List?) ?? _entries;
          _amount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved successfully')),
        );
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message']?.toString() ?? 'Failed to save entry';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openEditGoal() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditGoalView(
          goalId: widget.goalId,
          initialName: _name,
          initialTarget: _targetAmount.toStringAsFixed(0),
          initialNotes: _notes ?? '',
        ),
      ),
    );

    if (changed == true) {
      await _fetchGoal();
    }
  }

  String _formatEntryTitle(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const Text(
                    'GOAL DETAILS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _openEditGoal,
                    icon: const Icon(Icons.edit_outlined, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goal card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.authCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_targetAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You're \$${_amountAway.toStringAsFixed(0)} away from your goal!",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount selector
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundIconButton(
                      icon: Icons.remove,
                      onTap: () {
                        setState(() {
                          if (_amount > 0) _amount -= 50;
                          if (_amount < 0) _amount = 0;
                        });
                      },
                    ),
                    Container(
                      width: 110,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Text(
                          _amount.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.add,
                      onTap: () {
                        setState(() {
                          _amount += 50;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Save / cancel
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Entry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Savings history
              const Text(
                'Savings History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? const Center(
                            child: Text(
                              'No entries yet. Start saving!',
                              style: TextStyle(fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry =
                                  _entries[index] as Map<String, dynamic>;
                              final bool positive =
                                  entry['type']?.toString() == 'saved';
                              final numAmount =
                                  (entry['amount'] as num?) ?? 0;
                              final amountText =
                                  numAmount.toStringAsFixed(0);

                              DateTime? created;
                              if (entry['createdAt'] != null) {
                                try {
                                  created =
                                      DateTime.parse(entry['createdAt']);
                                } catch (_) {}
                              }
                              final title = created != null
                                  ? _formatEntryTitle(created)
                                  : (positive ? 'Saved' : 'Spent');

                              final subtitle =
                                  entry['note']?.toString().isNotEmpty == true
                                      ? entry['note'].toString()
                                      : (positive
                                          ? 'Saved entry'
                                          : 'Spent entry');

                              return _HistoryTile(
                                title: title,
                                subtitle: subtitle,
                                amountText: amountText,
                                positive: positive,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // quick add +50 saved
          setState(() {
            _amount += 50;
          });
        },
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amountText;
  final bool positive;

  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.authCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            (positive ? '+' : '-') +
                amountText.replaceAll(RegExp(r'[+\-]'), ''),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
