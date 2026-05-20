// lib/services/firestore_service.dart
//
// Drop-in replacement for DatabaseHelper.
// Every method returns the same types your screens already expect
// (Map<String, dynamic>, List<Map<String, dynamic>>, int, void).
//
// ── Setup ────────────────────────────────────────────────────────────────────
// 1. Add to pubspec.yaml:
//      cloud_firestore: ^5.0.0
//      firebase_core: ^3.0.0        (already done)
//
// 2. In main.dart, before runApp():
//      await Firebase.initializeApp(
//        options: DefaultFirebaseOptions.currentPlatform,
//      );
//
// 3. In every screen, replace:
//      final db = DatabaseHelper.instance;
//    with:
//      final db = FirestoreService.instance;
//
// 4. Firestore collection structure:
//      /vehicles/{docId}          – vehicle fields
//      /vehicles/{docId}/services/{docId} – sub-collection
//      /stock/{docId}             – stock items
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // Singleton ─────────────────────────────────────────────────────────────────
  static final FirestoreService instance = FirestoreService._init();
  FirestoreService._init();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection references ──────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _db.collection('vehicles');

  CollectionReference<Map<String, dynamic>> get _stock =>
      _db.collection('stock');

  CollectionReference<Map<String, dynamic>> _services(String vehicleDocId) =>
      _vehicles.doc(vehicleDocId).collection('services');

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a Firestore doc snapshot into the same Map your screens expect.
  /// Adds an 'id' field that mirrors the SQLite integer id.
  /// We store Firestore's string docId in the map under 'firestoreId'
  /// and keep 'id' as a stable integer hash so existing code never breaks.
  Map<String, dynamic> _docToMap(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    data['firestoreId'] = doc.id;
    // Give every record a stable integer id derived from the docId so all
    // comparison/notification code that does  `v['id'] as int`  keeps working.
    data['id'] = data['intId'] ?? doc.id.hashCode.abs();
    return data;
  }

  /// Looks up the Firestore docId for a given integer 'id'.
  Future<String?> _vehicleDocId(int intId) async {
    final snap = await _vehicles
        .where('intId', isEqualTo: intId)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  Future<String?> _stockDocId(int intId) async {
    final snap = await _stock
        .where('intId', isEqualTo: intId)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  Future<String?> _serviceDocId(String vehicleDocId, int intId) async {
    final snap = await _services(vehicleDocId)
        .where('intId', isEqualTo: intId)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  // ── VEHICLES ───────────────────────────────────────────────────────────────

  /// Insert a vehicle. Returns a stable integer id (like SQLite's row id).
  /// Throws if vehicle_number already exists (matches original ConflictAlgorithm.fail).
  Future<int> insertVehicle(Map<String, dynamic> data) async {
    final number =
        (data['vehicle_number'] ?? '').toString().trim().toUpperCase();

    // Uniqueness check
    final existing = await _vehicles
        .where('vehicle_number', isEqualTo: number)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Vehicle number already exists');
    }

    // Generate a stable int id
    final intId = DateTime.now().millisecondsSinceEpoch;
    final payload = Map<String, dynamic>.from(data);
    payload['vehicle_number'] = number;
    payload['intId'] = intId;
    payload['created_at'] =
        payload['created_at'] ?? DateTime.now().toIso8601String();

    await _vehicles.add(payload);
    return intId;
  }

  /// Update vehicle by integer id.
  Future<int> updateVehicle(int id, Map<String, dynamic> data) async {
    final docId = await _vehicleDocId(id);
    if (docId == null) return 0;
    await _vehicles.doc(docId).update(data);
    return 1;
  }

  /// Fetch a vehicle by its plate number.
  Future<Map<String, dynamic>?> getVehicleByNumber(String number) async {
    final snap = await _vehicles
        .where('vehicle_number',
            isEqualTo: number.trim().toUpperCase())
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : _docToMap(snap.docs.first);
  }

  /// All vehicles ordered by created_at DESC.
  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    final snap = await _vehicles
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  /// Delete a vehicle and all its services (mirrors CASCADE behaviour).
  Future<void> deleteVehicle(int id) async {
    final docId = await _vehicleDocId(id);
    if (docId == null) return;

    // Delete sub-collection services first
    final serviceDocs = await _services(docId).get();
    final batch = _db.batch();
    for (final s in serviceDocs.docs) {
      batch.delete(s.reference);
    }
    batch.delete(_vehicles.doc(docId));
    await batch.commit();
  }

  // ── SERVICES ───────────────────────────────────────────────────────────────

  /// Insert a service under its vehicle. Returns a stable integer id.
  Future<int> insertService(Map<String, dynamic> data) async {
    final vehicleIntId = data['vehicle_id'] as int;
    final vehicleDocId = await _vehicleDocId(vehicleIntId);
    if (vehicleDocId == null) throw Exception('Vehicle not found');

    final intId = DateTime.now().millisecondsSinceEpoch;
    final payload = Map<String, dynamic>.from(data);
    payload['intId'] = intId;
    payload['created_at'] =
        payload['created_at'] ?? DateTime.now().toIso8601String();

    await _services(vehicleDocId).add(payload);
    return intId;
  }

  /// Services for a vehicle ordered by service_date DESC.
  Future<List<Map<String, dynamic>>> getServicesByVehicle(
      int vehicleId) async {
    final docId = await _vehicleDocId(vehicleId);
    if (docId == null) return [];

    final snap = await _services(docId)
        .orderBy('service_date', descending: true)
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  /// Services whose next_service_date is today or within the next 2 days.
  /// Joins vehicle data manually (Firestore has no SQL JOIN).
  Future<List<Map<String, dynamic>>> getUpcomingServices() async {
    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final twoDaysStr = _dateStr(today.add(const Duration(days: 2)));

    final vehicleSnap = await _vehicles.get();
    final List<Map<String, dynamic>> result = [];

    for (final vDoc in vehicleSnap.docs) {
      final vData = _docToMap(vDoc);
      final serviceSnap = await _services(vDoc.id)
          .where('next_service_date', isGreaterThanOrEqualTo: todayStr)
          .where('next_service_date', isLessThanOrEqualTo: twoDaysStr)
          .get();

      for (final sDoc in serviceSnap.docs) {
        final sData = _docToMap(sDoc);
        // Attach vehicle fields (mirrors the SQL JOIN columns)
        sData['vehicle_number'] = vData['vehicle_number'];
        sData['owner_name']     = vData['owner_name'];
        sData['phone']          = vData['phone'];
        result.add(sData);
      }
    }

    result.sort((a, b) => (a['next_service_date'] ?? '')
        .compareTo(b['next_service_date'] ?? ''));
    return result;
  }

  /// Vehicle-level reminders (reminder_date >= today).
  Future<List<Map<String, dynamic>>> getVehicleReminders() async {
    final todayStr = _dateStr(DateTime.now());

    final snap = await _vehicles
        .where('reminder_date', isGreaterThanOrEqualTo: todayStr)
        .orderBy('reminder_date')
        .get();

    return snap.docs.map((doc) {
      final v = _docToMap(doc);
      // Shape the map exactly like the SQL query your RemindersScreen expects
      return <String, dynamic>{
        'id':               v['id'],
        'firestoreId':      v['firestoreId'],
        'vehicle_number':   v['vehicle_number'] ?? '',
        'owner_name':       v['owner_name'] ?? '',
        'phone':            v['phone'] ?? '',
        'next_service_date': v['reminder_date'] ?? '',
        'reminder_time':    v['reminder_time'] ?? '',
        'service_name':     v['reminder_note'] ?? '',
        'description':      '',
        'status':           '',
        'reminder_note':    v['reminder_note'] ?? '',
      };
    }).toList();
  }

  /// Delete a service by integer id (searches across all vehicles).
  Future<void> deleteService(int id) async {
    final vehicleSnap = await _vehicles.get();
    for (final vDoc in vehicleSnap.docs) {
      final sDocId = await _serviceDocId(vDoc.id, id);
      if (sDocId != null) {
        await _services(vDoc.id).doc(sDocId).delete();
        return;
      }
    }
  }

  // ── STOCK ──────────────────────────────────────────────────────────────────

  /// Insert a stock item. Returns a stable integer id.
  Future<int> insertStock(Map<String, dynamic> data) async {
    final intId = DateTime.now().millisecondsSinceEpoch;
    final payload = Map<String, dynamic>.from(data);
    payload['intId'] = intId;
    payload['created_at'] =
        payload['created_at'] ?? DateTime.now().toIso8601String();
    await _stock.add(payload);
    return intId;
  }

  /// All stock ordered by part_name ASC.
  Future<List<Map<String, dynamic>>> getAllStock() async {
    final snap =
        await _stock.orderBy('part_name').get();
    return snap.docs.map(_docToMap).toList();
  }

  /// Update only the quantity of a stock item.
  Future<void> updateStockQty(int id, int qty) async {
    final docId = await _stockDocId(id);
    if (docId == null) return;
    await _stock.doc(docId).update({'quantity': qty});
  }

  /// Update all fields of a stock item.
  Future<void> updateStock(int id, Map<String, dynamic> data) async {
    final docId = await _stockDocId(id);
    if (docId == null) return;
    await _stock.doc(docId).update(data);
  }

  /// Delete a stock item.
  Future<void> deleteStock(int id) async {
    final docId = await _stockDocId(id);
    if (docId == null) return;
    await _stock.doc(docId).delete();
  }

  // ── Utility ────────────────────────────────────────────────────────────────
  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}