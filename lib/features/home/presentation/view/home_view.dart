// home_view.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../common/widgets/spendsense_bottom_nav_bar.dart';

enum _ProfileMenuAction { editProfile, logout }

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;

  bool _loading = true;

  Map<String, dynamic>? _goal; // single goal (or null)
  List<Map<String, dynamic>> _wants = [];
  List<Map<String, dynamic>> _needs = [];

  String? _firstName; // ✅ for personalized greeting

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        prefs.getString('authToken') ??
        prefs.getString('accessToken');
  }

  // ✅ Try to get name from SharedPreferences first.
  // If not found, fallback to parsing it from goal/user payload (if present).
  Future<void> _loadFirstName() async {
    final prefs = await SharedPreferences.getInstance();

    // common keys people store after login/register
    final fullName = (prefs.getString('name') ??
            prefs.getString('fullName') ??
            prefs.getString('username') ??
            prefs.getString('userName') ??
            prefs.getString('displayName') ??
            '')
        .trim();

    if (fullName.isNotEmpty) {
      final first = fullName.split(RegExp(r'\s+')).first.trim();
      if (first.isNotEmpty) {
        _firstName = first;
        return;
      }
    }
  }

  Future<void> _loadHome() async {
    setState(() => _loading = true);

    try {
      await _loadFirstName();

      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1) goal
      Map<String, dynamic>? goal;
      final goalRes =
          await http.get(Uri.parse('${ApiEndpoints.goals}/me'), headers: headers);
      if (goalRes.statusCode == 200) {
        goal = jsonDecode(goalRes.body) as Map<String, dynamic>;
      } else {
        goal = null; // 404 = no goal yet
      }

      // ✅ fallback: try to infer firstName from API payload if available
      if ((_firstName == null || _firstName!.isEmpty) && goal != null) {
        final possibleName = (goal['userName'] ??
                goal['username'] ??
                goal['name'] ??
                goal['fullName'] ??
                '')
            .toString()
            .trim();
        if (possibleName.isNotEmpty) {
          _firstName = possibleName.split(RegExp(r'\s+')).first.trim();
        }
      }

      // 2) wants
      final wantsRes =
          await http.get(Uri.parse(ApiEndpoints.wants), headers: headers);
      final wantsList = wantsRes.statusCode == 200
          ? (jsonDecode(wantsRes.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      // 3) needs
      final needsRes =
          await http.get(Uri.parse(ApiEndpoints.needs), headers: headers);
      final needsList = needsRes.statusCode == 200
          ? (jsonDecode(needsRes.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _goal = goal;
        _wants = wantsList;
        _needs = needsList;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load home: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── UI helpers ───────────────────────────────────────────────────────────

  Map<String, dynamic>? get _latestWant {
    if (_wants.isEmpty) return null;
    // wants already sorted desc in backend
    return _wants.first;
  }

  int get _skippedThisWeekCount {
    final now = DateTime.now();
    return _wants.where((w) {
      if ((w['status'] ?? '') != 'skipped') return false;
      final createdAt = w['createdAt']?.toString();
      if (createdAt == null) return false;
      final dt = DateTime.tryParse(createdAt);
      if (dt == null) return false;
      return now.difference(dt).inDays <= 7;
    }).length;
  }

  double get _skippedThisWeekTotal {
    final now = DateTime.now();
    double sum = 0;
    for (final w in _wants) {
      if ((w['status'] ?? '') != 'skipped') continue;
      final createdAt = w['createdAt']?.toString();
      final dt = createdAt != null ? DateTime.tryParse(createdAt) : null;
      if (dt == null) continue;
      if (now.difference(dt).inDays <= 7) {
        sum += ((w['price'] as num?)?.toDouble() ?? 0);
      }
    }
    return sum;
  }

  double get _goalTarget => (_goal?['targetAmount'] as num?)?.toDouble() ?? 0;
  double get _goalCurrent => (_goal?['currentAmount'] as num?)?.toDouble() ?? 0;

  String get _goalName => (_goal?['name']?.toString().trim().isNotEmpty == true)
      ? _goal!['name'].toString()
      : 'Set a goal';

  double get _goalProgress {
    if (_goalTarget <= 0) return 0;
    final p = _goalCurrent / _goalTarget;
    return p.clamp(0, 1);
  }

  String get _greetingName {
    final n = (_firstName ?? '').trim();
    return n.isEmpty ? '' : n;
  }

  void _openGoalDetails() {
    if (_goal == null) {
      Navigator.of(context).pushNamed(AppRoutes.addGoal).then((_) => _loadHome());
      return;
    }

    Navigator.of(context)
        .pushNamed(
          AppRoutes.goalDetails,
          arguments: {
            'goalId': (_goal?['_id'] ?? '').toString(),
            'name': _goalName,
            'targetAmount': _goalTarget,
            'currentAmount': _goalCurrent,
            'notes': _goal?['notes']?.toString(),
          },
        )
        .then((_) => _loadHome());
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.of(context).pushNamed(AppRoutes.stats);
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.addGoal).then((_) => _loadHome());
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications coming soon 🔔')),
        );
        break;
      case 4:
        Navigator.of(context).pushNamed(AppRoutes.profile);
        break;
    }
  }

  void _logout() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      bottomNavigationBar: SpendSenseBottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onNavTap,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(text: 'Hello'),
                                  if (_greetingName.isNotEmpty)
                                    TextSpan(text: ' $_greetingName'),
                                  const TextSpan(text: ' 👋'),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuButton<_ProfileMenuAction>(
                            onSelected: (value) {
                              switch (value) {
                                case _ProfileMenuAction.editProfile:
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.profile);
                                  break;
                                case _ProfileMenuAction.logout:
                                  _logout();
                                  break;
                              }
                            },
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            itemBuilder: (context) => const [
                              PopupMenuItem<_ProfileMenuAction>(
                                value: _ProfileMenuAction.editProfile,
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit Profile'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem<_ProfileMenuAction>(
                                value: _ProfileMenuAction.logout,
                                child: ListTile(
                                  leading: Icon(Icons.logout),
                                  title: Text('Logout'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                            child: Container(
                              height: 36,
                              width: 36,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                size: 22,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ✅ real-time banner (same logic you already had)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.authCard,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.attach_money_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _skippedThisWeekCount == 0
                                    ? "No skipped temptations yet this week. You’ve got this 💪"
                                    : "You’ve skipped $_skippedThisWeekCount temptations this week! That’s Rs${_skippedThisWeekTotal.toStringAsFixed(0)} closer to your goal",
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ✅ Replace buggy tiles with “Add Wants / Add Needs” row (NO zebra overflow)
                      Row(
                        children: [
                          Expanded(
                            child: _AddRowCard(
                              label: 'Add Wants',
                              onTap: () {
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.wants)
                                    .then((_) => _loadHome());
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AddRowCard(
                              label: 'Add Needs',
                              onTap: () {
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.needs)
                                    .then((_) => _loadHome());
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // goal card (unchanged)
                      InkWell(
                        onTap: _openGoalDetails,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.authCard,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saving for',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _goalName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: _goalProgress,
                                  backgroundColor: Colors.white,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _goal == null
                                    ? 'Tap to set your goal'
                                    : 'Rs${_goalCurrent.toStringAsFixed(0)} of Rs${_goalTarget.toStringAsFixed(0)} saved',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // latest want section (unchanged)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _latestWant?['name']?.toString() ??
                                              'No wants yet',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _latestWant == null
                                              ? 'Log a temptation to see it here'
                                              : 'Status: ${_latestWant?['status'] ?? 'pending'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context)
                                                .pushNamed(AppRoutes.allWants)
                                                .then((_) => _loadHome());
                                          },
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.authCard,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: const Text(
                                              'View Wants',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _latestWant == null
                                              ? ''
                                              : 'Rs${((_latestWant?['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // impulse log summary header (unchanged)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Impulse Log',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.allWants)
                                  .then((_) => _loadHome());
                            },
                            child: const Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // summary card (unchanged)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.authCard,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Saved',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs${_goalCurrent.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.list_alt,
                                        size: 18, color: Colors.amber),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_wants.length} wants',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined,
                                        size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_needs.length} needs',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context)
                                          .pushNamed(AppRoutes.allNeeds)
                                          .then((_) => _loadHome());
                                    },
                                    child: const Text('View Needs'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// ✅ “Add Wants / Add Needs” card like your 2nd image (safe: no overflow)
class _AddRowCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddRowCard({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.authCard,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
