import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../common/widgets/spendsense_bottom_nav_bar.dart';

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  int _currentIndex = 1;

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _goal;
  List<Map<String, dynamic>> _wants = [];
  List<Map<String, dynamic>> _needs = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
        return;
      }

      Map<String, dynamic>? goal;
      final goalRes = await http.get(
        Uri.parse('${ApiEndpoints.goals}/me'),
        headers: _headers(token),
      );
      if (goalRes.statusCode == 200) {
        goal = jsonDecode(goalRes.body) as Map<String, dynamic>;
      } else {
        goal = null;
      }

      final wantsRes = await http.get(
        Uri.parse(ApiEndpoints.wants),
        headers: _headers(token),
      );
      final wantsList = wantsRes.statusCode == 200
          ? (jsonDecode(wantsRes.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      final needsRes = await http.get(
        Uri.parse(ApiEndpoints.needs),
        headers: _headers(token),
      );
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
      setState(() => _error = 'Failed to load stats: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ----------------- Helpers / Calculations -----------------

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  DateTime? _wantEffectiveDate(Map<String, dynamic> w) {
    return _parseDate(w['updatedAt']) ?? _parseDate(w['createdAt']);
  }

  bool _isInLast7Days(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return now.difference(dt).inDays <= 7;
  }

  String _rs(num value) => "Rs${value.toStringAsFixed(0)}";

  double get _goalTarget => (_goal?['targetAmount'] as num?)?.toDouble() ?? 0;
  double get _goalCurrent => (_goal?['currentAmount'] as num?)?.toDouble() ?? 0;
  String get _goalName =>
      (_goal?['name']?.toString().trim().isNotEmpty == true)
          ? _goal!['name'].toString()
          : 'No goal yet';

  double get _goalProgress {
    if (_goalTarget <= 0) return 0;
    final p = _goalCurrent / _goalTarget;
    return p.clamp(0, 1);
  }

  // ✅ SAME streak rules as Home
  int get _impulseFreeStreakDays {
    if (_wants.isEmpty) return 0;

    DateTime? lastSkip;
    DateTime? lastPurchase;

    for (final w in _wants) {
      final status = (w['status'] ?? '').toString();
      final dt = _wantEffectiveDate(w);
      if (dt == null) continue;

      if (status == 'skipped') {
        if (lastSkip == null || dt.isAfter(lastSkip)) lastSkip = dt;
      } else if (status == 'purchased') {
        if (lastPurchase == null || dt.isAfter(lastPurchase)) lastPurchase = dt;
      }
    }

    if (lastSkip == null) return 0;
    if (lastPurchase != null && lastPurchase.isAfter(lastSkip)) return 0;

    final now = DateTime.now();
    final daysSinceSkip = now.difference(lastSkip).inDays.clamp(0, 9999);
    return 1 + daysSinceSkip;
  }

  // weekly aggregates
  double get _skippedThisWeekTotal {
    double sum = 0;
    for (final w in _wants) {
      if ((w['status'] ?? '') != 'skipped') continue;
      if (!_isInLast7Days(_wantEffectiveDate(w))) continue;
      sum += ((w['price'] as num?)?.toDouble() ?? 0);
    }
    return sum;
  }

  double get _purchasedThisWeekTotal {
    double sum = 0;
    for (final w in _wants) {
      if ((w['status'] ?? '') != 'purchased') continue;
      if (!_isInLast7Days(_wantEffectiveDate(w))) continue;
      sum += ((w['price'] as num?)?.toDouble() ?? 0);
    }
    return sum;
  }

  double get _needsThisWeekTotal {
    double sum = 0;
    for (final n in _needs) {
      final dt = _parseDate(n['createdAt']) ?? _parseDate(n['updatedAt']);
      if (!_isInLast7Days(dt)) continue;
      sum += ((n['price'] as num?)?.toDouble() ?? 0);
    }
    return sum;
  }

  double get _savedLastWeek => _skippedThisWeekTotal;

  // ✅ Level based on streak days
  int get _level {
    final d = _impulseFreeStreakDays;
    if (d >= 30) return 5;
    if (d >= 14) return 4;
    if (d >= 7) return 3;
    if (d >= 3) return 2;
    return 1;
  }

  String get _levelMessage {
    final d = _impulseFreeStreakDays;
    if (d == 0) return "Start today. One skip starts your streak ✅";
    if (d < 3) return "Nice start. Keep it alive 🔥";
    if (d < 7) return "You’re building discipline 💪";
    if (d < 14) return "Strong control. Don’t break it 👊";
    if (d < 30) return "Elite level. Stay consistent ✅";
    return "Master tier 🏆";
  }

  // ----------------- Navigation -----------------

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
        break;
      case 1:
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.addGoal).then((_) => _loadStats());
        break;
      case 3:
        Navigator.of(context).pushNamed(AppRoutes.alerts);
        break;
      case 4:
        Navigator.of(context).pushNamed(AppRoutes.profile);
        break;
    }
  }

  void _openGoalProgress() {
    Navigator.of(context).pushNamed(AppRoutes.goalProgress);
  }

  Widget _starsRow(int level) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < level;
        return Icon(
          Icons.star_rounded,
          size: 20,
          color: filled ? Colors.amber : Colors.grey.shade300,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,      bottomNavigationBar: SpendSenseBottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onNavTap,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
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
                      const Center(
                        child: Text(
                          "YOUR PROGRESS",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),

                      _SoftCard(
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.savings_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Total Saved",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              _rs(_goalCurrent),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "🔥  Impulse-Free Streak",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                Text(
                                  "$_impulseFreeStreakDays days",
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: (_impulseFreeStreakDays / 30).clamp(0, 1),
                                backgroundColor: Colors.white,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _impulseFreeStreakDays == 0
                                  ? "Skip one want to start your streak."
                                  : "Keep it alive. Buying a want resets it to 0.",
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _openGoalProgress,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF163E6B),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.track_changes_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Savings On Goals",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.trending_up_rounded,
                                              color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Saved last 7 days",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _rs(_savedLastWeek),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.shopping_cart_outlined,
                                              color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Spent on wants (purchased)",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "-${_rs(_purchasedThisWeekTotal)}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
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

                      const SizedBox(height: 12),

                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Goal: $_goalName",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: _goalProgress,
                                backgroundColor: Colors.white,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _goal == null
                                  ? "Set a goal to start tracking progress."
                                  : "${_rs(_goalCurrent)} of ${_rs(_goalTarget)} saved",
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _starsRow(_level),
                                const SizedBox(width: 10),
                                Text(
                                  "Level-$_level",
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Streak: $_impulseFreeStreakDays days",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _levelMessage,
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniChip(
                                    label: "Skipped: ${_rs(_skippedThisWeekTotal)}",
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MiniChip(
                                    label: "Needs: ${_rs(_needsThisWeekTotal)}",
                                    icon: Icons.shopping_bag_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.authCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MiniChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
