import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../features/alerts/data/datasources/alerts_local_datasource.dart';
import '../../../../features/alerts/data/models/alert_model.dart';
import '../../../common/widgets/spendsense_bottom_nav_bar.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  int _currentIndex = 3;

  final _ds = AlertsLocalDataSource();

  bool _loading = true;
  List<AlertModel> _items = [];
  AlertModel? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _ds.getAll();
    final next = await _ds.getNextReminder();
    if (!mounted) return;
    setState(() {
      _items = all;
      _next = next;
      _loading = false;
    });
  }

  Future<void> _confirmClear({
    required String title,
    required Future<void> Function() onClear,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await onClear();
      await _load();
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _inTime(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'in ${diff.inHours} hr';
    return 'in ${diff.inDays} day(s)';
  }

  IconData _icon(AlertType t) {
    switch (t) {
      case AlertType.reminder:
        return Icons.alarm_rounded;
      case AlertType.progress:
        return Icons.emoji_events_rounded;
      case AlertType.action:
      default:
        return Icons.notifications_active_rounded;
    }
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
        break;
      case 1:
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.stats, (r) => false);
        break;
      case 2:
        Navigator.of(context).pushNamed(AppRoutes.addGoal);
        break;
      case 3:
        break;
      case 4:
        Navigator.of(context).pushNamed(AppRoutes.profile);
        break;
    }
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
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "ALERTS",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),

                  // ✅ Clear menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'clear_all') {
                        await _confirmClear(
                          title: "Clear all alerts?",
                          onClear: () => _ds.clearAll(),
                        );
                      }
                      if (value == 'clear_actions') {
                        await _confirmClear(
                          title: "Clear action alerts?",
                          onClear: () => _ds.clearByType(AlertType.action),
                        );
                      }
                      if (value == 'clear_reminders') {
                        await _confirmClear(
                          title: "Clear reminder alerts?",
                          onClear: () => _ds.clearByType(AlertType.reminder),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'clear_all', child: Text("Clear all")),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'clear_actions', child: Text("Clear actions only")),
                      PopupMenuItem(value: 'clear_reminders', child: Text("Clear reminders only")),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (_next != null) ...[
                _SoftCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.schedule_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Next reminder",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _next!.scheduledFor == null
                                  ? "No reminder scheduled"
                                  : _inTime(_next!.scheduledFor!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_next!.scheduledFor != null)
                        Text(
                          "${_next!.scheduledFor!.hour.toString().padLeft(2, '0')}:${_next!.scheduledFor!.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                _SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "No alerts yet",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "When you skip, purchase, or set reminders, they’ll show up here.",
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._items.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SoftCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Icon(_icon(a.type), color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.message,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _timeAgo(a.createdAt),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
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
