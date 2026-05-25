import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sms_service.dart';

/// Runs a periodic timer that checks all loaded reminders.
/// When the current time matches a reminder's scheduled date+time,
/// it fires an SMS via [SmsService].
///
/// Usage:
///   SmsSchedulerService.start(reminders);   // call after loadReminders()
///   SmsSchedulerService.stop();             // call in dispose()
class SmsSchedulerService {
  static Timer? _timer;

  // Track which reminder IDs have already had an SMS sent this session
  // so we don't spam on every tick.
  static final Set<String> _sentIds = {};

  /// Start (or restart) the scheduler with the current reminder list.
  /// [reminders] is the same list used in RemindersScreen — each map must have:
  ///   • next_service_date  (String, YYYY-MM-DD)
  ///   • reminder_time      (String, HH:mm, default 09:00)
  ///   • phone              (String)
  ///   • owner_name, vehicle_number, service_name, description, reminder_note
  static void start(List<Map<String, dynamic>> reminders) {
    stop(); // cancel any existing timer first

    // Check every 30 seconds — lightweight, won't drain battery
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndSend(reminders);
    });

    // Also run immediately on start
    _checkAndSend(reminders);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Clear sent-IDs (call when reminders are reloaded so newly-due
  /// reminders are re-evaluated).
  static void resetSentIds() => _sentIds.clear();

  static void _checkAndSend(List<Map<String, dynamic>> reminders) {
    final now = DateTime.now();

    for (final item in reminders) {
      final phone    = (item['phone'] ?? '').toString().trim();
      final dateStr  = (item['next_service_date'] ?? '').toString().trim();
      final timeStr  = (item['reminder_time'] ?? '09:00').toString().trim();

      // Skip if no phone or no date
      if (phone.isEmpty || dateStr.isEmpty) continue;

      // Build a unique key for this reminder
      final key = '${item['vehicle_number']}_${dateStr}_$timeStr';

      // Skip if already sent this session
      if (_sentIds.contains(key)) continue;

      try {
        final date      = DateTime.parse(dateStr);
        final parts     = timeStr.split(':');
        final scheduled = DateTime(
          date.year, date.month, date.day,
          int.parse(parts[0]),
          int.parse(parts.length > 1 ? parts[1] : '0'),
        );

        // Fire if we're within the same minute as the scheduled time
        final diff = now.difference(scheduled).inMinutes;
        if (diff >= 0 && diff < 1) {
          _sentIds.add(key); // mark immediately to avoid duplicate calls
          _sendSms(item, phone, dateStr);
        }
      } catch (e) {
        debugPrint('[SmsScheduler] Date parse error for $key: $e');
      }
    }
  }

  static Future<void> _sendSms(
    Map<String, dynamic> item,
    String phone,
    String dateStr,
  ) async {
    final message = SmsService.buildReminderMessage(
      ownerName:     item['owner_name']    ?? '',
      vehicleNumber: item['vehicle_number'] ?? '',
      serviceName:   item['service_name']   ?? '',
      serviceDate:   dateStr,
      description:   item['description'],
      reminderNote:  item['reminder_note'],
    );

    final ok = await SmsService.sendSms(phoneNumber: phone, message: message);
    debugPrint(ok
        ? '[SmsScheduler] ✅ SMS sent to $phone'
        : '[SmsScheduler] ❌ SMS failed for $phone');
  }
}