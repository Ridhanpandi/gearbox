import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';           // ← new
import '../services/sms_scheduler_service.dart'; // ← new

const kPrimary   = Color(0xFFFF4D00);
const kPrimaryDk = Color(0xFFFF4D00);
const kBg        = Color(0xFFFFDAB9);
const kCard      = Color(0xFFFFFFFF);
const kTextDark  = Color(0xFF1A1A2E);
const kTextMid   = Color(0xFF6B7280);
const kGreen     = Color(0xFF22C55E);
const kRed       = Color(0xFFFF4D00);
const kYellow    = Color(0xFFFF4D00);
const kBlue      = Color(0xFF3B82F6);
const kPurple    = Color(0xFF2D2B5E);

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  final db = FirestoreService.instance;
  List<Map<String, dynamic>> upcoming = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    NotificationService.init();
    loadReminders();
  }

  @override
  void dispose() {
    SmsSchedulerService.stop(); // ← stop timer when screen closes
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> loadReminders() async {
    setState(() => _loading = true);

    final services    = await db.getUpcomingServices();
    final vehicleRems = await db.getVehicleReminders();

    final all = [...services, ...vehicleRems];
    all.sort((a, b) =>
        (a['next_service_date'] ?? '').compareTo(b['next_service_date'] ?? ''));

    setState(() {
      upcoming = all;
      _loading = false;
    });
    _fadeCtrl.forward(from: 0);

    // ── Schedule push notifications ───────────────────────────────────────
    for (int i = 0; i < upcoming.length; i++) {
      final item    = upcoming[i];
      final dateStr = item['next_service_date'] ?? '';
      final timeStr = item['reminder_time'] ?? '09:00';
      if (dateStr.isNotEmpty) {
        try {
          final date      = DateTime.parse(dateStr);
          final timeParts = timeStr.split(':');
          final scheduled = DateTime(
            date.year, date.month, date.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
          if (scheduled.isAfter(DateTime.now())) {
            await NotificationService.scheduleReminder(
              id: i + 1,
              vehicleNumber: item['vehicle_number'] ?? '',
              serviceName:   item['service_name']   ?? '',
              scheduledDateTime: scheduled,
            );
          }
        } catch (_) {}
      }
    }

    // ── Start SMS scheduler with fresh reminder list ───────────────────────
    SmsSchedulerService.resetSentIds();
    SmsSchedulerService.start(upcoming);
  }

  // ── Urgency helpers ───────────────────────────────────────────────────────
  int daysUntil(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 999;
    try {
      final target = DateTime.parse(dateStr);
      final today  = DateTime.now();
      final d = DateTime(today.year,  today.month,  today.day);
      final t = DateTime(target.year, target.month, target.day);
      return t.difference(d).inDays;
    } catch (_) { return 999; }
  }

  Color  _urgencyColor(int days) => days == 0 ? kRed : days <= 1 ? kYellow : kBlue;
  String _urgencyLabel(int days) => days == 0 ? 'Due Today' : days == 1 ? 'Due Tomorrow' : days <= 7 ? 'In $days Days' : 'Upcoming';
  IconData _urgencyIcon(int days) => days == 0 ? Icons.warning_rounded : days == 1 ? Icons.access_time_filled_rounded : Icons.event_rounded;

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : upcoming.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimary, kPrimaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 24),
          child: Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Reminders',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                  Text('All upcoming reminders',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            // ── Test push notification ─────────────────────────────────────
            GestureDetector(
              onTap: () async {
                final sample = upcoming.isNotEmpty ? upcoming.first : null;
                final title = sample != null
                    ? '🔧 ${sample['service_name'] ?? 'Service Reminder'}'
                    : '🔧 Test Reminder';
                final body = sample != null
                    ? [
                        sample['vehicle_number'],
                        sample['owner_name'],
                        if ((sample['reminder_note'] ?? '').toString().isNotEmpty)
                          sample['reminder_note'],
                      ]
                        .where((e) => e != null && e.toString().isNotEmpty)
                        .join(' · ')
                    : 'Notifications are working!';

                await NotificationService.showInstant(title: title, body: body);
                if (mounted) _snack('Test notification sent!', kGreen);
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 20),
              ),
            ),

            const SizedBox(width: 8),

            // ── Test SMS button ────────────────────────────────────────────
            GestureDetector(
              onTap: () async {
                final sample = upcoming.firstWhere(
                  (r) => (r['phone'] ?? '').toString().isNotEmpty,
                  orElse: () => {},
                );

                if (sample.isEmpty) {
                  _snack('No reminder with a phone number found!', kRed);
                  return;
                }

                _snack('Sending test SMS…', kBlue);

                final message = SmsService.buildReminderMessage(
                  ownerName:     sample['owner_name']    ?? '',
                  vehicleNumber: sample['vehicle_number'] ?? '',
                  serviceName:   sample['service_name']   ?? 'Service Reminder',
                  serviceDate:   sample['next_service_date'] ?? '',
                  description:   sample['description'],
                  reminderNote:  sample['reminder_note'],
                );

                final ok = await SmsService.sendSms(
                  phoneNumber: sample['phone'],
                  message: message,
                );

                if (mounted) {
                  _snack(
                    ok ? '✅ Test SMS sent to ${sample['phone']}!' : '❌ SMS failed — check API key & phone.',
                    ok ? kGreen : kRed,
                  );
                }
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sms_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 56, color: kGreen),
          ),
          const SizedBox(height: 20),
          const Text('All Clear!',
              style: TextStyle(color: kTextDark, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('No upcoming reminders found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMid, fontSize: 14, height: 1.5)),
        ]),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: loadReminders,
      color: kPrimary,
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          itemCount: upcoming.length,
          itemBuilder: (ctx, i) {
            final days = daysUntil(upcoming[i]['next_service_date']);
            return _ReminderCard(
              data: upcoming[i],
              days: days,
              urgencyColor: _urgencyColor(days),
              urgencyLabel: _urgencyLabel(days),
              urgencyIcon:  _urgencyIcon(days),
              onCopied: (msg) => _snack(msg, kGreen),
              // ── Manual "Send SMS now" from the card ──────────────────────
              onSendSms: (item) async {
                final phone = (item['phone'] ?? '').toString().trim();
                if (phone.isEmpty) {
                  _snack('No phone number for this reminder!', kRed);
                  return;
                }
                _snack('Sending SMS…', kBlue);
                final message = SmsService.buildReminderMessage(
                  ownerName:     item['owner_name']    ?? '',
                  vehicleNumber: item['vehicle_number'] ?? '',
                  serviceName:   item['service_name']   ?? '',
                  serviceDate:   item['next_service_date'] ?? '',
                  description:   item['description'],
                  reminderNote:  item['reminder_note'],
                );
                final ok = await SmsService.sendSms(
                    phoneNumber: phone, message: message);
                if (mounted) {
                  _snack(
                    ok ? '✅ SMS sent to $phone!' : '❌ SMS failed — check API key.',
                    ok ? kGreen : kRed,
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ── Reminder Card ─────────────────────────────────────────────────────────────
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.data,
    required this.days,
    required this.urgencyColor,
    required this.urgencyLabel,
    required this.urgencyIcon,
    required this.onCopied,
    required this.onSendSms,
  });

  final Map<String, dynamic> data;
  final int days;
  final Color urgencyColor;
  final String urgencyLabel;
  final IconData urgencyIcon;
  final void Function(String) onCopied;
  final void Function(Map<String, dynamic>) onSendSms; // ← new

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '09:00 AM';
    try {
      final p = t.split(':');
      int h = int.parse(p[0]), m = int.parse(p[1]);
      final period = h >= 12 ? 'PM' : 'AM';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    } catch (_) { return t; }
  }

  @override
  Widget build(BuildContext context) {
    final phone        = data['phone'] ?? '';
    final timeStr      = _formatTime(data['reminder_time']);
    final reminderNote = (data['reminder_note'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1 — vehicle number + urgency badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['vehicle_number'] ?? '',
                    style: const TextStyle(
                        color: kPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                _UrgencyBadge(
                    color: urgencyColor,
                    icon: urgencyIcon,
                    label: urgencyLabel),
              ],
            ),

            const SizedBox(height: 2),
            Text(data['owner_name'] ?? '',
                style: const TextStyle(color: kTextMid, fontSize: 13)),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),

            // Row 2 — service info
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_rounded, color: kPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['service_name'] ?? '',
                        style: const TextStyle(
                            color: kTextDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if ((data['description'] ?? '').isNotEmpty)
                      Text(data['description'],
                          style: const TextStyle(color: kTextMid, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // Row 3 — date + time chips
            Row(children: [
              _chip(
                icon: Icons.calendar_month_rounded,
                label: data['next_service_date'] ?? '—',
                color: urgencyColor,
              ),
              const SizedBox(width: 8),
              _chip(
                icon: Icons.access_time_rounded,
                label: timeStr,
                color: kPrimary,
              ),
            ]),

            // Reminder note bubble
            if (reminderNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kYellow.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kYellow.withValues(alpha: 0.30), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_rounded, color: kYellow, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reminderNote,
                          style: const TextStyle(color: kTextDark, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],

            // Phone copy button + Send SMS button
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                // Copy phone
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        onCopied('Phone $phone copied!');
                      },
                      icon: Icon(Icons.phone_rounded, size: 16, color: urgencyColor),
                      label: Text(
                        '${data['owner_name']} · $phone',
                        style: TextStyle(
                            color: urgencyColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: urgencyColor, width: 1.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ── Send SMS now ───────────────────────────────────────────
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => onSendSms(data),
                    icon: const Icon(Icons.sms_rounded, size: 16),
                    label: const Text('SMS',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String label, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Urgency Badge ─────────────────────────────────────────────────────────────
class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge(
      {required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    );
  }
}