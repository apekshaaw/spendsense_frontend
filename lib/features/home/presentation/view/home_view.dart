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

  Map<String, dynamic>? _goal;
  List<Map<String, dynamic>> _wants = [];
  List<Map<String, dynamic>> _needs = [];

  // ✅ NEW: user profile fetched from /api/auth/me
  Map<String, dynamic>? _me;

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

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<void> _loadHome() async {
    setState(() => _loading = true);

    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
        return;
      }

      // ✅ 0) profile (real name for Hello <name>)
      Map<String, dynamic>? me;
      final meRes = await http.get(
        Uri.parse(ApiEndpoints.profile),
        headers: _headers(token),
      );
      if (meRes.statusCode == 200) {
        me = Map<String, dynamic>.from(jsonDecode(meRes.body) as Map);
      } else {
        me = null;
      }

      // 1) goal
      Map<String, dynamic>? goal;
      final goalRes =
          await http.get(Uri.parse('${ApiEndpoints.goals}/me'), headers: _headers(token));
      if (goalRes.statusCode == 200) {
        goal = jsonDecode(goalRes.body) as Map<String, dynamic>;
      } else {
        goal = null;
      }

      // 2) wants
      final wantsRes =
          await http.get(Uri.parse(ApiEndpoints.wants), headers: _headers(token));
      final wantsList = wantsRes.statusCode == 200
          ? (jsonDecode(wantsRes.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      // 3) needs
      final needsRes =
          await http.get(Uri.parse(ApiEndpoints.needs), headers: _headers(token));
      final needsList = needsRes.statusCode == 200
          ? (jsonDecode(needsRes.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _me = me;
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

  // ------------------ Helpers ------------------

  String get _firstName {
    final raw = (_me?['name'] ?? '').toString().trim();
    if (raw.isEmpty) return 'there';
    return raw.split(' ').first;
  }

  Map<String, dynamic>? get _latestWant => _wants.isEmpty ? null : _wants.first;

  double get _goalTarget => (_goal?['targetAmount'] as num?)?.toDouble() ?? 0;
  double get _goalCurrent => (_goal?['currentAmount'] as num?)?.toDouble() ?? 0;

  String get _goalName =>
      (_goal?['name']?.toString().trim().isNotEmpty == true)
          ? _goal!['name'].toString()
          : 'Set a goal';

  double get _goalProgress {
    if (_goalTarget <= 0) return 0;
    final p = _goalCurrent / _goalTarget;
    return p.clamp(0, 1);
  }

  String _rs(num v) => 'Rs${v.toStringAsFixed(0)}';

  // ✅ NEW: motivational banner message based on real goal progress
  String get _motivationLine {
    if (_goal == null || _goalTarget <= 0) {
      return "Set a goal today — your future self will thank you 🙌";
    }

    final remaining = (_goalTarget - _goalCurrent).clamp(0, _goalTarget);
    final pct = (_goalProgress * 100).round();

    if (_goalProgress >= 0.95) {
      return "You’re almost there 🔥 Only ${_rs(remaining)} left to hit your goal!";
    }
    if (_goalProgress >= 0.75) {
      return "Great progress 💪 You’re $pct% there — keep going!";
    }
    if (_goalProgress >= 0.40) {
      return "Momentum matters ✅ You’re $pct% closer to $_goalName.";
    }
    return "Small wins add up 👊 You’re $pct% in don’t stop now.";
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
        Navigator.of(context).pushNamed(AppRoutes.alerts);
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
                      // ------------------ Top Row ------------------
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
                                  const TextSpan(text: 'Hello '),
                                  TextSpan(text: _firstName),
                                  const TextSpan(text: ' 👋'),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuButton<_ProfileMenuAction>(
                            onSelected: (value) {
                              switch (value) {
                                case _ProfileMenuAction.editProfile:
                                  Navigator.of(context).pushNamed(AppRoutes.profile);
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

                      // ------------------ Motivational Banner ------------------
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                Icons.flag_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _motivationLine,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ------------------ Add Wants / Add Needs (New UI) ------------------
                      Row(
                        children: [
                          Expanded(
                            child: _AddPillCard(
                              title: 'Add Wants',
                              onTap: () {
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.wants)
                                    .then((_) => _loadHome());
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AddPillCard(
                              title: 'Add Needs',
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

                      // ------------------ Goal Card (with View Stats button) ------------------
                      InkWell(
                        onTap: _openGoalDetails,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.authCard,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // top row inside goal card
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Saving for',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pushNamed(AppRoutes.goalProgress);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'View Stats',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
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
                                    : '${_rs(_goalCurrent)} of ${_rs(_goalTarget)} saved',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // latest want
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _latestWant?['name']?.toString() ?? 'No wants yet',
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
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context)
                                                .pushNamed(AppRoutes.allWants)
                                                .then((_) => _loadHome());
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.authCard,
                                              borderRadius: BorderRadius.circular(18),
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
                                              : _rs(((_latestWant?['price'] as num?)?.toDouble() ?? 0)),
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

                      // impulse log header
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

                      // summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                              _rs(_goalCurrent),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    const Icon(Icons.shopping_bag_outlined, size: 18),
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

class _AddPillCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _AddPillCard({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.authCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                ),
              ),
            ),
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
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
