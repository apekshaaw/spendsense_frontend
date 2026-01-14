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

  Map<String, dynamic>? _me;

  static const String _goalCompleteShownIdKey = 'goal_complete_shown_goal_id_v1';
  static const String _goalCompleteAnim = 'assets/anim/thumbs_up.lottie';

  static bool _motivationShownThisAppRun = false;
  static const String _motivationAnim = 'assets/anim/happy_face.lottie';

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

      // 0) profile
      Map<String, dynamic>? me;
      final meRes = await http.get(
        Uri.parse(ApiEndpoints.profile),
        headers: _headers(token),
      );
      if (meRes.statusCode == 200) {
        me = Map<String, dynamic>.from(jsonDecode(meRes.body) as Map);
      }

      // 1) goal
      Map<String, dynamic>? goal;
      final goalRes = await http.get(
        Uri.parse('${ApiEndpoints.goals}/me'),
        headers: _headers(token),
      );
      if (goalRes.statusCode == 200) {
        goal = jsonDecode(goalRes.body) as Map<String, dynamic>;
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

      // goal completed popup
      final nowCompleted = _isGoalCompleted;
      if (!wasCompleted && nowCompleted) {
        _maybeShowGoalCompletedPopup();
      } else if (nowCompleted) {
        _maybeShowGoalCompletedPopup();
      }

      // motivation popup once per app run
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

  // Date helpers
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int _daysBetweenStart(DateTime from, DateTime to) {
    return _startOfDay(to).difference(_startOfDay(from)).inDays;
  }

  DateTime? _wantEffectiveDate(Map<String, dynamic> w) {
    return _parseDate(w['updatedAt']) ?? _parseDate(w['createdAt']);
  }

  /// STREAK RULES
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

    if (lastPurchased != null) {
      return _daysBetweenStart(lastPurchased, now).clamp(0, 9999);
    }

    if (firstSkipped != null) {
      return (_daysBetweenStart(firstSkipped, now) + 1).clamp(1, 9999);
    }

    return 0;
  }

  int get _levelFromStreak {
    final d = _impulseFreeStreakDays;
    if (d >= 30) return 5;
    if (d >= 14) return 4;
    if (d >= 7) return 3;
    if (d >= 3) return 2;
    return 1;
  }

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
    if (_isGoalCompleted || _goal == null) {
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

  // ✅ Goal icon based on goal name
  IconData _iconForGoalName(String name) {
    final n = name.toLowerCase();

    if (n.contains('car') || n.contains('bike') || n.contains('scooter')) {
      return Icons.directions_car_rounded;
    }
    if (n.contains('shoe') || n.contains('shoes') || n.contains('sneaker')) {
      return Icons.directions_run_rounded;
    }
    if (n.contains('dress') || n.contains('clothes') || n.contains('jacket')) {
      return Icons.checkroom_rounded;
    }
    if (n.contains('phone') || n.contains('iphone') || n.contains('mobile')) {
      return Icons.smartphone_rounded;
    }
    if (n.contains('laptop') || n.contains('macbook')) {
      return Icons.laptop_mac_rounded;
    }
    if (n.contains('dyson') || n.contains('vacuum') || n.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }
    if (n.contains('travel') || n.contains('trip') || n.contains('vacation')) {
      return Icons.flight_takeoff_rounded;
    }
    if (n.contains('course') || n.contains('study') || n.contains('college')) {
      return Icons.school_rounded;
    }
    if (n.contains('emergency') || n.contains('saving') || n.contains('savings')) {
      return Icons.savings_rounded;
    }

    return Icons.flag_rounded;
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
      backgroundColor: Colors.white,      bottomNavigationBar: SpendSenseBottomNavBar(
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.authCard,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                                        Navigator.of(context).pushNamed(
                                            AppRoutes.goalProgress);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
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

                              // ✅ The moving person ON the SAME progress line
                              const SizedBox(height: 12),
                              _MovingPersonProgressLine(
                                progress: _goalProgress,
                                goalIcon: _iconForGoalName(_goalName),
                                // change these if you want
                                moveDuration: const Duration(milliseconds: 1400),
                                pauseAfterMove: const Duration(seconds: 6),
                              ),
                              const SizedBox(height: 10),

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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
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
                                              : _rs(((_latestWant?['price']
                                                          as num?)
                                                      ?.toDouble() ??
                                                  0)),
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

                      // Goal Archive link
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

class _MovingPersonProgressLine extends StatefulWidget {
  final double progress; // 0..1
  final IconData goalIcon;

  final Duration moveDuration;
  final Duration pauseAfterMove;

  const _MovingPersonProgressLine({
    required this.progress,
    required this.goalIcon,
    this.moveDuration = const Duration(seconds: 2),
    this.pauseAfterMove = const Duration(seconds: 3),
  });

  @override
  State<_MovingPersonProgressLine> createState() =>
      _MovingPersonProgressLineState();
}

class _MovingPersonProgressLineState extends State<_MovingPersonProgressLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _anim; // 0..target

  Timer? _loopTimer;
  double _target = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.moveDuration);
    _setTargetAndStart(widget.progress);
  }

  @override
  void didUpdateWidget(covariant _MovingPersonProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);

    if ((oldWidget.progress - widget.progress).abs() > 0.001) {
      _setTargetAndStart(widget.progress);
    }
  }

  void _setTargetAndStart(double p) {
    _loopTimer?.cancel();
    _controller.stop();
    _controller.reset();

    _target = p.clamp(0.0, 1.0);

    _anim = Tween<double>(begin: 0.0, end: _target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _playOnceAndLoop();
  }

  void _playOnceAndLoop() {
  _loopTimer?.cancel();

  if (!mounted) return;

  if (_target <= 0.0) {
    setState(() {});
    return;
  }

  // Start the first move
  _controller.forward(from: 0);

  // ✅ Infinite loop: when animation finishes, wait -> restart -> repeat forever
  _controller.removeStatusListener(_statusListener);
  _controller.addStatusListener(_statusListener);
}

void _statusListener(AnimationStatus status) {
  if (status != AnimationStatus.completed) return;
  if (!mounted) return;

  _loopTimer?.cancel();
  _loopTimer = Timer(widget.pauseAfterMove, () {
    if (!mounted) return;
    _controller.reset();
    _controller.forward(from: 0); // statusListener will trigger again on complete
  });
}

  @override
void dispose() {
  _loopTimer?.cancel();
  _controller.removeStatusListener(_statusListener);
  _controller.dispose();
  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    // ✅ Give the whole area height so icons are NOT clipped
    const double trackHeight = 8;     // bar thickness
    const double iconSize = 30;       // circle size
    const double totalHeight = 36;    // stack height (fixes clipping)

    return SizedBox(
      height: totalHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final currentPos = _target <= 0 ? 0.0 : _anim.value;

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // Keep moving icon fully inside (0..1)
              final usableWidth = (width - iconSize).clamp(0.0, width);
              final left = usableWidth * currentPos;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // ✅ Center the progress bar vertically inside the bigger box
                  Align(
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: trackHeight,
                        value: widget.progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // ✅ Moving person icon (centered on the line)
                  Positioned(
                    left: left,
                    top: (totalHeight - iconSize) / 2,
                    child: Container(
                      height: iconSize,
                      width: iconSize,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.9),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_walk_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // ✅ Goal icon at end (centered on the same line)
                  Positioned(
                    right: 0,
                    top: (totalHeight - iconSize) / 2,
                    child: Container(
                      height: iconSize,
                      width: iconSize,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.9),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          widget.goalIcon,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
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
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.emoji_emotions, size: 64)),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: DotLottieLoader.fromAsset(
        assetPath,
        frameBuilder: (ctx, dotlottie) {
          if (dotlottie == null) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          }

          return Lottie.memory(
            dotlottie.animations.values.single,
            repeat: true,
            fit: BoxFit.contain,
          );
        },
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.emoji_emotions, size: 64)),
      ),
    );
  }
}
