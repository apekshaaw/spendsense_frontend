import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:spendsense_frontend/core/constants/app_colors.dart';
import 'package:spendsense_frontend/features/home/data/datasources/home_remote_datasource.dart';
import 'package:spendsense_frontend/features/home/data/models/goal_model.dart';
import 'package:spendsense_frontend/features/home/data/models/want_model.dart';

enum ProgressRange { week, month, all }

class GoalProgressView extends StatefulWidget {
  const GoalProgressView({super.key});

  @override
  State<GoalProgressView> createState() => _GoalProgressViewState();
}

class _GoalProgressViewState extends State<GoalProgressView> {
  final _ds = HomeRemoteDataSource();

  bool _loading = true;
  String? _error;

  GoalModel? _goal;
  List<WantModel> _wants = [];

  ProgressRange _range = ProgressRange.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final goal = await _ds.getMyGoal();
      final wants = await _ds.getWants();

      if (!mounted) return;
      setState(() {
        _goal = goal;
        _wants = wants;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load goal progress: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- Helpers ----------------

  String _rs(num v) => "Rs${v.toStringAsFixed(0)}";

  DateTime _startForRange(ProgressRange r) {
    final now = DateTime.now();

    if (r == ProgressRange.week) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    }

    if (r == ProgressRange.month) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    }

    // ALL: don’t go back to year 2000 (too many points).
    // Use earliest entry date if available, otherwise last 30 days.
    final g = _goal;
    if (g != null && g.entries.isNotEmpty) {
      final withDates = g.entries.where((e) => e.createdAt != null).toList();
      if (withDates.isNotEmpty) {
        withDates.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
        final dt = withDates.first.createdAt!;
        return DateTime(dt.year, dt.month, dt.day);
      }
    }
    return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
  }

  List<DateTime> get _daysInRange {
    final now = DateTime.now();
    final start = _startForRange(_range);

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(now.year, now.month, now.day);

    final days = <DateTime>[];
    DateTime cursor = startDay;
    while (!cursor.isAfter(endDay)) {
      days.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  List<GoalEntryModel> get _filteredEntries {
    final g = _goal;
    if (g == null) return [];

    final start = _startForRange(_range);

    final entries = g.entries
        .where((e) => e.createdAt != null)
        .where((e) => !e.createdAt!.isBefore(start))
        .toList();

    entries.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    return entries;
  }

  // map[dateOnly] = netSavedForThatDay (saved - spent)
  Map<DateTime, double> get _dailyNet {
    final map = <DateTime, double>{};

    for (final e in _filteredEntries) {
      final dt = e.createdAt!;
      final day = DateTime(dt.year, dt.month, dt.day);

      final amt = e.amount;
      final delta = (e.type == 'spent') ? -amt : amt;

      map[day] = (map[day] ?? 0) + delta;
    }

    return map;
  }

  // Convert daily net to cumulative curve points (one point per day)
  List<_Point> get _curvePoints {
    final days = _daysInRange;
    if (days.isEmpty) return [];

    final net = _dailyNet;

    double running = 0;
    final points = <_Point>[];
    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      running += (net[d] ?? 0);
      points.add(_Point(x: i.toDouble(), y: running));
    }

    return points;
  }

  // Weekday labels (Sun/Mon/...) for WEEK
  String _weekdayShort(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }

  // Pie chart: wants skipped vs purchased (in selected range)
  int get _skippedCountInRange {
    final start = _startForRange(_range);
    return _wants.where((w) {
      if (w.createdAt == null) return false;
      if (w.createdAt!.isBefore(start)) return false;
      return (w.status ?? '') == 'skipped';
    }).length;
  }

  int get _purchasedCountInRange {
    final start = _startForRange(_range);
    return _wants.where((w) {
      if (w.createdAt == null) return false;
      if (w.createdAt!.isBefore(start)) return false;
      return (w.status ?? '') == 'purchased';
    }).length;
  }

  double get _skippedTotalInRange {
    final start = _startForRange(_range);
    double sum = 0;
    for (final w in _wants) {
      if (w.createdAt == null) continue;
      if (w.createdAt!.isBefore(start)) continue;
      if ((w.status ?? '') != 'skipped') continue;
      sum += (w.price ?? 0);
    }
    return sum;
  }

  double get _purchasedTotalInRange {
    final start = _startForRange(_range);
    double sum = 0;
    for (final w in _wants) {
      if (w.createdAt == null) continue;
      if (w.createdAt!.isBefore(start)) continue;
      if ((w.status ?? '') != 'purchased') continue;
      sum += (w.price ?? 0);
    }
    return sum;
  }

  String get _headline {
    final g = _goal;
    if (g == null) return "Set a goal to start tracking.";

    final remaining = max(0, g.targetAmount - g.currentAmount);

    if (remaining <= 0) return "Goal completed. That’s discipline ✅";
    if (remaining <= g.targetAmount * 0.05) return "You’re nearly there. Finish strong 🔥";
    if (remaining <= g.targetAmount * 0.20) return "You’re close. Keep stacking wins 💪";
    return "Small wins add up. Stay consistent 👊";
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Goal progress 🔥",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        _SoftCard(
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),

                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _headline,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _goal == null
                                  ? "Create a goal from Home → Add Goal."
                                  : "${_rs(_goal!.currentAmount)} of ${_rs(_goal!.targetAmount)} saved",
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Range selector
                      _SoftCard(
                        child: Row(
                          children: [
                            _RangeChip(
                              label: "Week",
                              selected: _range == ProgressRange.week,
                              onTap: () => setState(() => _range = ProgressRange.week),
                            ),
                            const SizedBox(width: 10),
                            _RangeChip(
                              label: "Month",
                              selected: _range == ProgressRange.month,
                              onTap: () => setState(() => _range = ProgressRange.month),
                            ),
                            const SizedBox(width: 10),
                            _RangeChip(
                              label: "All",
                              selected: _range == ProgressRange.all,
                              onTap: () => setState(() => _range = ProgressRange.all),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Line chart (REAL-APP LOOK)
                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Your saving trend",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: _curvePoints.length <= 1
                                  ? const Center(
                                      child: Text(
                                        "No progress entries yet.\nAdd savings to see your graph.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.textGrey),
                                      ),
                                    )
                                  : CustomPaint(
                                      painter: _SmoothAreaLineChartPainter(_curvePoints),
                                    ),
                            ),

                            // X axis labels
                            const SizedBox(height: 8),
                            if (_curvePoints.length > 1)
                              _range == ProgressRange.week
                                  ? Row(
                                      children: _daysInRange.map((d) {
                                        return Expanded(
                                          child: Text(
                                            _weekdayShort(d),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textGrey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  : Row(
                                      children: _buildDateTicksForMonthAll().map((t) {
                                        return Expanded(
                                          child: Text(
                                            t,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textGrey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),

                            const SizedBox(height: 10),
                            const Text(
                              "Every entry you add becomes a point on this graph ✅",
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pie chart
                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "By temptations",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  height: 120,
                                  width: 120,
                                  child: CustomPaint(
                                    painter: _PiePainter(
                                      skipped: _skippedCountInRange,
                                      purchased: _purchasedCountInRange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _LegendRow(
                                        label: "Skipped",
                                        value: "$_skippedCountInRange  •  ${_rs(_skippedTotalInRange)}",
                                        icon: Icons.check_circle_outline,
                                      ),
                                      const SizedBox(height: 10),
                                      _LegendRow(
                                        label: "Purchased",
                                        value: "$_purchasedCountInRange  •  ${_rs(_purchasedTotalInRange)}",
                                        icon: Icons.shopping_cart_outlined,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "More skips = more progress. Keep it up 💪",
                                        style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Recent entries
                      _SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Recent progress",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            if ((_goal?.entries.isEmpty ?? true))
                              const Text(
                                "No entries yet. Add progress to start your streak.",
                                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                              )
                            else
                              ..._goal!.entries
                                  .where((e) => e.createdAt != null)
                                  .take(6)
                                  .map((e) {
                                final isSpent = e.type == 'spent';
                                final dt = e.createdAt!;
                                final dateText =
                                    "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSpent ? Icons.remove_circle_outline : Icons.add_circle_outline,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          e.note?.trim().isNotEmpty == true
                                              ? e.note!.trim()
                                              : (isSpent ? "Spent" : "Saved"),
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Text(
                                        (isSpent ? "- " : "+ ") + _rs(e.amount),
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        dateText,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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

  // Month/All: show 6 tick labels so it doesn’t clutter
  List<String> _buildDateTicksForMonthAll() {
    final days = _daysInRange;
    if (days.isEmpty) return [];

    const ticks = 6;
    final labels = <String>[];

    for (int i = 0; i < ticks; i++) {
      final idx = ((days.length - 1) * (i / (ticks - 1))).round();
      final d = days[idx];
      labels.add("${d.day}/${d.month}");
    }
    return labels;
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

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _LegendRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// --------- Chart painters (smooth + gradient, real-app look) ---------

class _Point {
  final double x;
  final double y;
  _Point({required this.x, required this.y});
}

class _SmoothAreaLineChartPainter extends CustomPainter {
  final List<_Point> points;
  _SmoothAreaLineChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;

    // soft grid
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minY = points.map((p) => p.y).reduce(min);
    final maxY = points.map((p) => p.y).reduce(max);
    final rangeY = max(1.0, maxY - minY);
    final maxX = points.last.x;

    Offset mapPoint(_Point p) {
      final x = (p.x / maxX) * size.width;
      final yNorm = (p.y - minY) / rangeY;
      final y = size.height - (yNorm * size.height);
      return Offset(x, y);
    }

    final mapped = points.map(mapPoint).toList();

    // Smooth path (quadratic curve through midpoints)
    Path smoothPath(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);

      for (int i = 0; i < pts.length - 1; i++) {
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

        path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);

        // last segment: finish to last point
        if (i == pts.length - 2) {
          path.quadraticBezierTo(p2.dx, p2.dy, p2.dx, p2.dy);
        }
      }
      return path;
    }

    final linePath = smoothPath(mapped);

    // Area fill path
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          AppColors.primary.withOpacity(0.28),
          AppColors.primary.withOpacity(0.03),
        ],
      );

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // Highlight last point
    final last = mapped.last;
    final dotOuter = Paint()..color = AppColors.primary.withOpacity(0.25);
    final dotInner = Paint()..color = AppColors.primary;

    canvas.drawCircle(last, 8, dotOuter);
    canvas.drawCircle(last, 4, dotInner);
  }

  @override
  bool shouldRepaint(covariant _SmoothAreaLineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _PiePainter extends CustomPainter {
  final int skipped;
  final int purchased;

  _PiePainter({required this.skipped, required this.purchased});

  @override
  void paint(Canvas canvas, Size size) {
    final total = max(1, skipped + purchased);
    final skippedSweep = (skipped / total) * 2 * pi;
    final purchasedSweep = (purchased / total) * 2 * pi;

    final rect = Offset.zero & size;

    final skippedPaint = Paint()..color = AppColors.primary.withOpacity(0.95);
    final purchasedPaint = Paint()..color = AppColors.primary.withOpacity(0.25);

    double start = -pi / 2;

    canvas.drawArc(rect, start, skippedSweep, true, skippedPaint);
    start += skippedSweep;
    canvas.drawArc(rect, start, purchasedSweep, true, purchasedPaint);

    // donut hole
    final holePaint = Paint()..color = const Color(0xFFF6F8FF);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.28, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.skipped != skipped || oldDelegate.purchased != purchased;
  }
}
