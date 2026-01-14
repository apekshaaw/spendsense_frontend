import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
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

  // ✅ user profile fetched from /api/auth/me
  Map<String, dynamic>? _me;

  // ✅ Goal completion popup control (show once per goal)
  static const String _goalCompleteShownIdKey = 'goal_complete_shown_goal_id_v1';
  static const String _goalCompleteAnim = 'assets/anim/thumbs_up.lottie';

  // ✅ NEW: motivation popup should show once per APP RUN (not every navigation)
  static bool _motivationShownThisAppRun = false;

  // ✅ you said you'll add this asset
  static const String _motivationAnim = 'assets/anim/happy_face.lottie';

  // ✅ Goal Archive route (won’t break compile even if not in AppRoutes yet)
  static const String _goalArchiveRoute = '/goal-archive';

  final Random _rng = Random();

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

      // ✅ 0) profile
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
      final goalRes = await http.get(
        Uri.parse('${ApiEndpoints.goals}/me'),
        headers: _headers(token),
      );
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

      // capture old completion state BEFORE updating state
      final wasCompleted = _isGoalCompleted;

      setState(() {
        _me = me;
        _goal = goal;
        _wants = wantsList;
        _needs = needsList;
      });

      // ✅ show goal completed popup (your existing logic)
      final nowCompleted = _isGoalCompleted;
      if (!wasCompleted && nowCompleted) {
        _maybeShowGoalCompletedPopup();
      } else if (nowCompleted) {
        _maybeShowGoalCompletedPopup();
      }

      // ✅ NEW: show motivation popup once per app run (not on navigation back)
      _maybeShowMotivationPopupOnAppOpen();
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

  bool get _isGoalCompleted =>
      _goal != null && _goalTarget > 0 && _goalCurrent >= _goalTarget;

  double get _remaining =>
      (_goalTarget - _goalCurrent).clamp(0, _goalTarget).toDouble();

  String _rs(num v) => 'Rs${v.toStringAsFixed(0)}';

  // ✅ Date helpers
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int _daysBetweenStart(DateTime from, DateTime to) {
    return _startOfDay(to).difference(_startOfDay(from)).inDays;
  }

  DateTime? _wantEffectiveDate(Map<String, dynamic> w) {
    // ✅ use updatedAt first because status changes later
    return _parseDate(w['updatedAt']) ?? _parseDate(w['createdAt']);
  }

  /// ✅ STREAK RULES (exactly as you asked):
  /// - 0 if user has never skipped anything yet
  /// - becomes 1 instantly when they skip once (same day)
  /// - increases daily even with no new actions
  /// - resets to 0 when any want becomes purchased (needs do NOT affect)
  int get _impulseFreeStreakDays {
    final now = DateTime.now();

    DateTime? lastPurchased;
    DateTime? firstSkipped;

    for (final w in _wants) {
      final status = (w['status'] ?? '').toString();
      final dt = _wantEffectiveDate(w);
      if (dt == null) continue;

      if (status == 'purchased') {
        if (lastPurchased == null || dt.isAfter(lastPurchased)) {
          lastPurchased = dt;
        }
      }

      if (status == 'skipped') {
        if (firstSkipped == null || dt.isBefore(firstSkipped)) {
          firstSkipped = dt;
        }
      }
    }

    // If any purchase happened, streak is days since LAST purchased (starts at 0 on purchase day)
    if (lastPurchased != null) {
      return _daysBetweenStart(lastPurchased, now).clamp(0, 9999);
    }

    // No purchases ever:
    // If user has skipped at least once, streak starts at 1 on the day of first skip.
    if (firstSkipped != null) {
      return (_daysBetweenStart(firstSkipped, now) + 1).clamp(1, 9999);
    }

    // No skips yet => 0
    return 0;
  }

  // ✅ Level based on STREAK DAYS (1..5)
  int get _levelFromStreak {
    final d = _impulseFreeStreakDays;
    if (d >= 30) return 5;
    if (d >= 14) return 4;
    if (d >= 7) return 3;
    if (d >= 3) return 2;
    return 1;
  }

  // ✅ motivational banner message (handles completed goals properly)
  String get _motivationLine {
    if (_goal == null || _goalTarget <= 0) {
      return "Set a goal today — your future self will thank you 🙌";
    }

    if (_isGoalCompleted) {
      return "Goal achieved 🎉 You hit $_goalName. Set a new goal and keep the momentum 🔥";
    }

    final pct = (_goalProgress * 100).round();

    if (_goalProgress >= 0.95) {
      return "You’re almost there 🔥 Only ${_rs(_remaining)} left to hit your goal!";
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
    if (_isGoalCompleted) {
      Navigator.of(context).pushNamed(AppRoutes.addGoal).then((_) => _loadHome());
      return;
    }

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
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
  }

  // ------------------ GOAL COMPLETED POPUP ------------------

  Future<void> _maybeShowGoalCompletedPopup() async {
    if (!_isGoalCompleted) return;

    final goalId = (_goal?['_id'] ?? '').toString();
    if (goalId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShownFor = prefs.getString(_goalCompleteShownIdKey);

    if (alreadyShownFor == goalId) return;

    await prefs.setString(_goalCompleteShownIdKey, goalId);

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showGoalCompletedDialog();
    });
  }

  void _showGoalCompletedDialog() {
    bool dismissed = false;

    final messages = <String>[
      "Massive win 🎉 You completed “$_goalName”.\nNow set a new goal and keep the streak alive 🔥",
      "Let’s gooo 🚀 You hit your goal “$_goalName”.\nNew level unlocked — time to set the next one 💪",
      "Goal achieved ✅ You stayed consistent and it worked.\nSet your next goal right now!",
      "This is what discipline looks like 🏆\nYou reached “$_goalName”. Keep going — don’t stop here.",
      "You did it 🎯 Goal completed.\nFuture-you is proud. Set a new goal and keep building momentum.",
    ];

    final msg = messages[_rng.nextInt(messages.length)];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Anim(assetPath: _goalCompleteAnim),
              const SizedBox(height: 6),
              const Text(
                "Goal Completed 🎉",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  dismissed = true;
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => dismissed = true);

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (dismissed) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    });
  }

  // ------------------ MOTIVATION POPUP (ONCE PER APP RUN) ------------------

  void _maybeShowMotivationPopupOnAppOpen() {
    if (_motivationShownThisAppRun) return;
    _motivationShownThisAppRun = true;

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showMotivationDialog();
    });
  }

  void _showMotivationDialog() {
    final streak = _impulseFreeStreakDays;
    final lvl = _levelFromStreak;

    final goalLine = (_goal == null || _goalTarget <= 0)
        ? "Set a goal today and start stacking wins ✅"
        : _isGoalCompleted
            ? "You completed “$_goalName” 🎉 Set your next goal now."
            : "You’re ${(100 * _goalProgress).round()}% toward “$_goalName”. Only ${_rs(_remaining)} left.";

    final messages = <String>[
      "🔥 Day $streak.\nNo impulse buys. That’s discipline.\n$goalLine",
      "You’re on Day $streak ✅\nLevel $lvl energy.\nProtect the streak today.",
      "Momentum check 💪\nStreak: $streak days.\n$goalLine",
      "You’re doing great 👊\nStreak Day: $streak\nOne good choice today keeps it alive.",
      "Stay locked in ✅\n$streak days without buying a want.\n$goalLine",
    ];

    final msg = messages[_rng.nextInt(messages.length)];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Anim(assetPath: _motivationAnim),
              const SizedBox(height: 6),
              const Text(
                "Keep Going 🚀",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Let’s go',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final streakDays = _impulseFreeStreakDays;

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

                      // ✅ streak line under Hello
                      const SizedBox(height: 6),
                      Text(
                        "🔥 $streakDays day streak",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGrey,
                        ),
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

                      // ------------------ Add Wants / Add Needs ------------------
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

                      // ------------------ Goal Card ------------------
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
                                  if (_isGoalCompleted)
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pushNamed(AppRoutes.addGoal)
                                            .then((_) => _loadHome());
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        'Set new goal',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(AppRoutes.goalProgress);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                              if (_isGoalCompleted) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    "✅ Goal completed — set the next one!",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

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
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                    const Icon(Icons.list_alt, size: 18, color: Colors.amber),
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

                      // ✅ NEW: Goal Archive link at bottom
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context)
                                .pushNamed(_goalArchiveRoute)
                                .then((_) => _loadHome());
                          },
                          child: const Text(
                            'Goal Archive',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
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

class _Anim extends StatelessWidget {
  final String assetPath;
  const _Anim({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    final isDotLottie = assetPath.toLowerCase().endsWith('.lottie');

    if (!isDotLottie) {
      return SizedBox(
        height: 120,
        child: Lottie.asset(
          assetPath,
          repeat: true,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.emoji_emotions, size: 64),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: DotLottieLoader.fromAsset(
        assetPath,
        frameBuilder: (ctx, dotlottie) {
          if (dotlottie == null) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          return Lottie.memory(
            dotlottie.animations.values.single,
            repeat: true,
            fit: BoxFit.contain,
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.emoji_emotions, size: 64),
        ),
      ),
    );
  }
}
