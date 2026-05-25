import 'dart:convert';
import 'package:http/http.dart' as http;

/// Calls SMS Gateway Master REST API to send an SMS via your Android device.
/// Docs: https://sms-gateway-ae7e1.web.app/documentation
class SmsService {
  // ── 🔑 Replace with your key from: App → Settings → Gateway API ───────────
  static const String _apiKey = 'API_KEY';
  static const String _endpoint =
      'https://us-central1-sms-gateway-ae7e1.cloudfunctions.net/api_sms_send';

  /// Sends an SMS.
  /// [phoneNumber] must include country code e.g. +91XXXXXXXXXX
  /// Returns true if the API accepted the message (status 200).
  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      print('[SmsService] ⚠️  API key not set — skipping SMS send.');
      return false;
    }

    // Normalise: strip spaces/dashes, add +91 if no country code present
    String phone = phoneNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!phone.startsWith('+')) phone = '+91$phone';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _apiKey,
            },
            body: jsonEncode({
              'phoneNumber': phone,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[SmsService] ✅ Queued — smsId: ${data['smsId']}');
        return true;
      } else {
        print('[SmsService] ❌ HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[SmsService] ❌ Error: $e');
      return false;
    }
  }

  /// Builds the reminder SMS text for a vehicle service reminder.
  static String buildReminderMessage({
    required String ownerName,
    required String vehicleNumber,
    required String serviceName,
    required String serviceDate,
    String? description,
    String? reminderNote,
  }) {
    final lines = <String>[
      '🔧 Service Reminder',
      'Vehicle : $vehicleNumber',
      'Owner   : $ownerName',
      'Service : $serviceName',
      'Date    : $serviceDate',
      if (description != null && description.isNotEmpty)
        'Details : $description',
      if (reminderNote != null && reminderNote.isNotEmpty)
        'Note    : $reminderNote',
      '',
      'Please visit us on time. Thank you!',
    ];
    return lines.join('\n');
  }
}