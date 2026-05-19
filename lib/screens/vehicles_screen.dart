import 'dart:ui';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/notification_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const kPrimary   = Color(0xFFFF4D00);
const kPrimaryDk = Color(0xFFFF4D00);
const kBg        = Color(0xFFFFDAB9);
const kCard      = Color(0xFFFFFFFF);
const kTextDark  = Color(0xFF1A1A2E);
const kTextMid   = Color(0xFF6B7280);
const kBorder    = Color(0xFFE5E7EB);
const kGreen     = Color(0xFF22C55E);
const kRed       = Color(0xFFFF4D00);

// ── Shared input decoration factory ──────────────────────────────────────────
InputDecoration _inputDec(String label, {Widget? prefix, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kTextMid, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.8)),
    );

// ─────────────────────────────────────────────────────────────────────────────

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen>
    with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;
  List<Map<String, dynamic>> vehicles = [];
  final Map<int, List<Map<String, dynamic>>> _servicesCache = {};
  int? _expandedId;
  final searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    NotificationService.init();
    loadVehicles();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> loadVehicles() async {
    final list = await db.getAllVehicles();
    setState(() => vehicles = list);
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _loadServices(int vid) async {
    final svcs = await db.getServicesByVehicle(vid);
    setState(() => _servicesCache[vid] = svcs);
  }

  List<Map<String, dynamic>> get filtered {
    final q = searchCtrl.text.toLowerCase();
    if (q.isEmpty) return vehicles;
    return vehicles
        .where((v) =>
            (v['vehicle_number'] ?? '').toLowerCase().contains(q) ||
            (v['owner_name'] ?? '').toLowerCase().contains(q) ||
            (v['make'] ?? '').toLowerCase().contains(q))
        .toList();
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: _buildFab(),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [kPrimary, kPrimaryDk],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Row(children: [
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicles',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text('Tap a card to view services',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: TextField(
        controller: searchCtrl,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: kTextDark, fontSize: 14),
        decoration: _inputDec('Search by number, owner, make…',
            prefix:
                const Icon(Icons.search_rounded, color: kTextMid, size: 20)),
      ),
    );
  }

  // ── body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (filtered.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: loadVehicles,
      color: kPrimary,
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _buildVehicleCard(filtered[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_rounded,
                size: 48, color: kPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            vehicles.isEmpty ? 'No vehicles yet' : 'No results found',
            style: const TextStyle(
                color: kTextDark,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            vehicles.isEmpty
                ? 'Tap + to add your first vehicle'
                : 'Try a different search term',
            style: const TextStyle(color: kTextMid, fontSize: 14),
          ),
        ]),
      );

  // ── vehicle card ───────────────────────────────────────────────────────────
  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final vid = v['id'] as int;
    final isExpanded = _expandedId == vid;
    final services = _servicesCache[vid] ?? [];
    final total =
        services.fold<double>(0, (s, x) => s + ((x['cost'] ?? 0) as num));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isExpanded ? kPrimary : kBorder,
            width: isExpanded ? 1.8 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // top strip
        

        // header row
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (_expandedId == vid) {
              setState(() => _expandedId = null);
            } else {
              setState(() => _expandedId = vid);
              if (!_servicesCache.containsKey(vid)) await _loadServices(vid);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['vehicle_number'] ?? '',
                          style: const TextStyle(
                              color: kPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2)),
                      if ((v['owner_name'] ?? '').isNotEmpty)
                        Text(v['owner_name'],
                            style: const TextStyle(
                                color: kTextDark, fontSize: 13)),
                      if ('${v['make'] ?? ''} ${v['model'] ?? ''} ${v['year'] ?? ''}'
                              .trim()
                              .isNotEmpty)
                        Text(
                            '${v['make'] ?? ''} ${v['model'] ?? ''} ${v['year'] ?? ''}'
                                .trim(),
                            style: const TextStyle(
                                color: kTextMid, fontSize: 12)),
                      if ((v['phone'] ?? '').isNotEmpty)
                        Row(children: [
                          const Icon(Icons.phone_outlined,
                              size: 12, color: kTextMid),
                          const SizedBox(width: 4),
                          Text(v['phone'],
                              style: const TextStyle(
                                  color: kTextMid, fontSize: 12)),
                        ]),
                      if ((v['reminder_date'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            const Icon(Icons.notifications_active_rounded,
                                color: kPrimary, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              _formatReminderDisplay(
                                  v['reminder_date'], v['reminder_time']),
                              style: const TextStyle(
                                  color: kPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                            if ((v['reminder_note'] ?? '').isNotEmpty) ...[
                              const Text(' · ',
                                  style: TextStyle(
                                      color: kTextMid, fontSize: 11)),
                              Flexible(
                                child: Text(v['reminder_note'],
                                    style: const TextStyle(
                                        color: kTextMid, fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ]),
                        ),
                    ]),
              ),
              Column(children: [
                _actionIcon(Icons.edit_outlined, kPrimary,
                    () => _showEditVehicle(v)),
                _actionIcon(Icons.delete_outline, kRed,
                    () => _confirmDelete(v, vid)),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: kTextMid,
                  size: 22,
                ),
              ]),
            ]),
          ),
        ),

        // expanded services
        if (isExpanded) ...[
          const Divider(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  _chip('${services.length} Services', kPrimary),
                  const SizedBox(width: 8),
                  _chip('₹${total.toStringAsFixed(0)} Total', kGreen),
                ]),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddService(v),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add Service'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (services.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('No services recorded yet.',
                  style: TextStyle(color: kTextMid, fontSize: 13)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children:
                    services.map((s) => _buildServiceRow(s, vid)).toList(),
              ),
            ),
        ],
      ]),
    );
  }

  String _formatReminderDisplay(String? date, String? time) {
    if (date == null || date.isEmpty) return '';
    try {
      final d = DateTime.parse(date);
      final dateStr =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      if (time != null && time.isNotEmpty) return '$dateStr at $time';
      return dateStr;
    } catch (_) {
      return date;
    }
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      );

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );

  // ── service row ────────────────────────────────────────────────────────────
  Widget _buildServiceRow(Map<String, dynamic> s, int vid) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              const Icon(Icons.build_rounded, color: kPrimary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['service_name'] ?? '',
                    style: const TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if ((s['description'] ?? '').isNotEmpty)
                  Text(s['description'],
                      style:
                          const TextStyle(color: kTextMid, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if ((s['service_date'] ?? '').isNotEmpty)
                    _metaChip(Icons.calendar_today_rounded,
                        s['service_date'], kTextMid),
                  if ((s['next_service_date'] ?? '').isNotEmpty)
                    _metaChip(Icons.notifications_rounded,
                        s['next_service_date'], kPrimary),
                  _metaChip(
                      Icons.currency_rupee_rounded,
                      (s['cost'] ?? 0).toStringAsFixed(0),
                      kGreen),
                  _statusBadge(s['status'] ?? 'pending'),
                ]),
              ]),
        ),
        GestureDetector(
          onTap: () async {
            await db.deleteService(s['id']);
            await _loadServices(vid);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline, color: kRed, size: 15),
          ),
        ),
      ]),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _statusBadge(String status) {
    final isCompleted = status == 'completed';
    final color = isCompleted ? kGreen : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFab() => FloatingActionButton.extended(
        onPressed: showAddVehicle,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Vehicle',
            style: TextStyle(fontWeight: FontWeight.w700)),
      );

  // ── delete confirm ─────────────────────────────────────────────────────────
  Future<void> _confirmDelete(Map<String, dynamic> v, int vid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.65),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Vehicle',
            style: TextStyle(
                color: kTextDark, fontWeight: FontWeight.w800)),
        content: Text(
            'Delete ${v['vehicle_number']}? This will also remove all services.',
            style: const TextStyle(color: kTextMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: kTextMid))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (_expandedId == vid) setState(() => _expandedId = null);
      _servicesCache.remove(vid);
      await db.deleteVehicle(vid);
      loadVehicles();
    }
  }

  // ── ADD VEHICLE SHEET ──────────────────────────────────────────────────────
  void showAddVehicle() {
    final numCtrl      = TextEditingController();
    final ownerCtrl    = TextEditingController();
    final phoneCtrl    = TextEditingController();
    final makeCtrl     = TextEditingController();
    final modelCtrl    = TextEditingController();
    final yearCtrl     = TextEditingController();
    final reminderCtrl = TextEditingController();
    DateTime? reminderDate;
    TimeOfDay? reminderTime;
    final List<Map<String, TextEditingController>> serviceRows = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheetBody(
          ctx: ctx,
          title: 'Add Vehicle',
          icon: Icons.add_circle_outline_rounded,
          children: [
            _tf(numCtrl, 'Vehicle Number *',
                caps: TextCapitalization.characters),
            _tf(ownerCtrl, 'Owner Name'),
            _tf(phoneCtrl, 'Phone',
                keyboard: TextInputType.phone,
                prefix: const Icon(Icons.phone_outlined,
                    color: kTextMid, size: 18)),
            Row(children: [
              Expanded(child: _tf(makeCtrl, 'Make')),
              const SizedBox(width: 10),
              Expanded(child: _tf(modelCtrl, 'Model')),
            ]),
            _tf(yearCtrl, 'Year', keyboard: TextInputType.number),

            _sectionLabel('Services Done'),
            ...serviceRows.asMap().entries.map((e) => _serviceInputRow(
                e.value,
                () => setSheet(() => serviceRows.removeAt(e.key)))),
            _addRowButton(
                'Add Service',
                () => setSheet(() => serviceRows.add({
                      'name': TextEditingController(),
                      'cost': TextEditingController()
                    }))),

            _sectionLabel('Reminder'),
            _tf(reminderCtrl, 'Reminder note',
                maxLines: 2,
                prefix: const Icon(Icons.notifications_outlined,
                    color: kTextMid, size: 18)),
            _datePicker(
              ctx: ctx,
              date: reminderDate,
              label: 'Pick reminder date (optional)',
              onPicked: (d) => setSheet(() => reminderDate = d),
              onCleared: () => setSheet(() {
                reminderDate = null;
                reminderTime = null;
              }),
            ),
            if (reminderDate != null)
              _timePicker(
                ctx: ctx,
                time: reminderTime,
                onPicked: (t) => setSheet(() => reminderTime = t),
                onCleared: () => setSheet(() => reminderTime = null),
              ),

            _sheetButtons(
              ctx: ctx,
              onSave: () async {
                if (numCtrl.text.trim().isEmpty) return;

                // Step 1: Insert vehicle — isolated so only DB errors
                // trigger "already exists"
                int? vid;
                try {
                  final rt = reminderTime ??
                      const TimeOfDay(hour: 9, minute: 0);
                  vid = await db.insertVehicle({
                    'vehicle_number':
                        numCtrl.text.trim().toUpperCase(),
                    'owner_name': ownerCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'make': makeCtrl.text.trim(),
                    'model': modelCtrl.text.trim(),
                    'year': yearCtrl.text.trim(),
                    'reminder_note': reminderCtrl.text.trim(),
                    'reminder_date': reminderDate
                            ?.toIso8601String()
                            .split('T')
                            .first ??
                        '',
                    'reminder_time': reminderDate != null
                        ? '${rt.hour.toString().padLeft(2, '0')}:${rt.minute.toString().padLeft(2, '0')}'
                        : '',
                  });
                } catch (_) {
                  Navigator.pop(ctx);
                  _snack('Vehicle number already exists!', kRed);
                  return;
                }

                // Step 2: Notifications + services (non-blocking)
                try {
                  if (reminderDate != null) {
                    final rt = reminderTime ??
                        const TimeOfDay(hour: 9, minute: 0);
                    await NotificationService.scheduleReminder(
                      id: vid,
                      vehicleNumber:
                          numCtrl.text.trim().toUpperCase(),
                      serviceName:
                          reminderCtrl.text.trim().isNotEmpty
                              ? reminderCtrl.text.trim()
                              : 'Vehicle Reminder',
                      scheduledDateTime: DateTime(
                        reminderDate!.year,
                        reminderDate!.month,
                        reminderDate!.day,
                        rt.hour,
                        rt.minute,
                      ),
                    );
                  }
                  for (final row in serviceRows) {
                    final name = row['name']!.text.trim();
                    if (name.isEmpty) continue;
                    await db.insertService({
                      'vehicle_id': vid,
                      'service_name': name,
                      'cost':
                          double.tryParse(row['cost']!.text.trim()) ??
                              0.0,
                      'service_date': DateTime.now()
                          .toIso8601String()
                          .split('T')
                          .first,
                      'status': 'completed',
                    });
                  }
                } catch (e) {
                  debugPrint('Post-insert error: $e');
                }

                Navigator.pop(ctx);
                loadVehicles();
                _snack('Vehicle saved!', kGreen);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── EDIT VEHICLE SHEET ─────────────────────────────────────────────────────
  void _showEditVehicle(Map<String, dynamic> vehicle) {
    final ownerCtrl =
        TextEditingController(text: vehicle['owner_name'] ?? '');
    final phoneCtrl =
        TextEditingController(text: vehicle['phone'] ?? '');
    final makeCtrl =
        TextEditingController(text: vehicle['make'] ?? '');
    final modelCtrl =
        TextEditingController(text: vehicle['model'] ?? '');
    final yearCtrl =
        TextEditingController(text: vehicle['year'] ?? '');
    final reminderCtrl =
        TextEditingController(text: vehicle['reminder_note'] ?? '');
    DateTime? reminderDate;
    TimeOfDay? reminderTime;

    final exDate = vehicle['reminder_date'] ?? '';
    if (exDate.isNotEmpty) {
      try { reminderDate = DateTime.parse(exDate); } catch (_) {}
    }
    final exTime = vehicle['reminder_time'] ?? '';
    if (exTime.isNotEmpty) {
      try {
        final parts = exTime.split(':');
        reminderTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]));
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheetBody(
          ctx: ctx,
          title: 'Edit ${vehicle['vehicle_number']}',
          icon: Icons.edit_outlined,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: TextEditingController(
                    text: vehicle['vehicle_number']),
                readOnly: true,
                style: const TextStyle(color: kTextMid),
                decoration: _inputDec('Vehicle Number (locked)',
                    suffix: const Icon(Icons.lock_outline,
                        color: kTextMid, size: 16)),
              ),
            ),
            _tf(ownerCtrl, 'Owner Name'),
            _tf(phoneCtrl, 'Phone',
                keyboard: TextInputType.phone,
                prefix: const Icon(Icons.phone_outlined,
                    color: kTextMid, size: 18)),
            Row(children: [
              Expanded(child: _tf(makeCtrl, 'Make')),
              const SizedBox(width: 10),
              Expanded(child: _tf(modelCtrl, 'Model')),
            ]),
            _tf(yearCtrl, 'Year', keyboard: TextInputType.number),

            _sectionLabel('Reminder'),
            _tf(reminderCtrl, 'Reminder note',
                maxLines: 2,
                prefix: const Icon(Icons.notifications_outlined,
                    color: kTextMid, size: 18)),
            _datePicker(
              ctx: ctx,
              date: reminderDate,
              label: 'Pick reminder date (optional)',
              onPicked: (d) => setSheet(() => reminderDate = d),
              onCleared: () => setSheet(() {
                reminderDate = null;
                reminderTime = null;
              }),
            ),
            if (reminderDate != null)
              _timePicker(
                ctx: ctx,
                time: reminderTime,
                onPicked: (t) => setSheet(() => reminderTime = t),
                onCleared: () => setSheet(() => reminderTime = null),
              ),

            _sheetButtons(
              ctx: ctx,
              saveLabel: 'Update',
              onSave: () async {
                final rt =
                    reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
                await db.updateVehicle(vehicle['id'], {
                  'vehicle_number': vehicle['vehicle_number'],
                  'owner_name': ownerCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'make': makeCtrl.text.trim(),
                  'model': modelCtrl.text.trim(),
                  'year': yearCtrl.text.trim(),
                  'reminder_note': reminderCtrl.text.trim(),
                  'reminder_date': reminderDate
                          ?.toIso8601String()
                          .split('T')
                          .first ??
                      '',
                  'reminder_time': reminderDate != null
                      ? '${rt.hour.toString().padLeft(2, '0')}:${rt.minute.toString().padLeft(2, '0')}'
                      : '',
                });

                try {
                  if (reminderDate != null) {
                    await NotificationService.scheduleReminder(
                      id: vehicle['id'] as int,
                      vehicleNumber: vehicle['vehicle_number'] ?? '',
                      serviceName:
                          reminderCtrl.text.trim().isNotEmpty
                              ? reminderCtrl.text.trim()
                              : 'Vehicle Reminder',
                      scheduledDateTime: DateTime(
                        reminderDate!.year,
                        reminderDate!.month,
                        reminderDate!.day,
                        rt.hour,
                        rt.minute,
                      ),
                    );
                  } else {
                    await NotificationService.cancelReminder(
                        vehicle['id'] as int);
                  }
                } catch (e) {
                  debugPrint('Notification error: $e');
                }

                Navigator.pop(ctx);
                loadVehicles();
                _snack('Vehicle updated!', kGreen);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── ADD SERVICE SHEET ──────────────────────────────────────────────────────
  void _showAddService(Map<String, dynamic> vehicle) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    DateTime? serviceDate = DateTime.now();
    DateTime? nextServiceDate;
    TimeOfDay? nextServiceTime;
    String status = 'completed';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheetBody(
          ctx: ctx,
          title: 'Add Service',
          subtitle: vehicle['vehicle_number'],
          icon: Icons.build_outlined,
          children: [
            _tf(nameCtrl, 'Service Name *'),
            _tf(descCtrl, 'Description', maxLines: 2),
            _tf(costCtrl, 'Cost (₹)',
                keyboard: TextInputType.number,
                prefix: const Icon(Icons.currency_rupee_rounded,
                    color: kTextMid, size: 18)),

            _sectionLabel('Service Date'),
            _datePicker(
              ctx: ctx,
              date: serviceDate,
              label: 'Select service date',
              allowPast: true,
              onPicked: (d) => setModal(() => serviceDate = d),
              onCleared: () => setModal(() => serviceDate = null),
            ),

            _sectionLabel('Next Service Date & Reminder Time'),
            _datePicker(
              ctx: ctx,
              date: nextServiceDate,
              label: 'Select next service date (optional)',
              onPicked: (d) => setModal(() => nextServiceDate = d),
              onCleared: () => setModal(() {
                nextServiceDate = null;
                nextServiceTime = null;
              }),
            ),
            if (nextServiceDate != null)
              _timePicker(
                ctx: ctx,
                time: nextServiceTime,
                onPicked: (t) => setModal(() => nextServiceTime = t),
                onCleared: () =>
                    setModal(() => nextServiceTime = null),
              ),

            _sectionLabel('Status'),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: status,
                style: const TextStyle(color: kTextDark, fontSize: 14),
                decoration: _inputDec('Status',
                    prefix: const Icon(Icons.flag_outlined,
                        color: kTextMid, size: 18)),
                items: [
                  DropdownMenuItem(
                    value: 'completed',
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: kGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Completed',
                          style: TextStyle(color: kTextDark)),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Pending',
                          style: TextStyle(color: kTextDark)),
                    ]),
                  ),
                ],
                onChanged: (v) => setModal(() => status = v!),
              ),
            ),

            _sheetButtons(
              ctx: ctx,
              onSave: () async {
                if (nameCtrl.text.trim().isEmpty) return;

                final serviceDateStr = serviceDate != null
                    ? serviceDate!
                        .toIso8601String()
                        .split('T')
                        .first
                    : DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first;

                final nextDateStr = nextServiceDate != null
                    ? nextServiceDate!
                        .toIso8601String()
                        .split('T')
                        .first
                    : '';

                final serviceId = await db.insertService({
                  'vehicle_id': vehicle['id'],
                  'service_name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'cost': double.tryParse(costCtrl.text) ?? 0,
                  'service_date': serviceDateStr,
                  'next_service_date': nextDateStr,
                  'status': status,
                });

                if (nextServiceDate != null) {
                  try {
                    final rt = nextServiceTime ??
                        const TimeOfDay(hour: 9, minute: 0);
                    final scheduled = DateTime(
                      nextServiceDate!.year,
                      nextServiceDate!.month,
                      nextServiceDate!.day,
                      rt.hour,
                      rt.minute,
                    );
                    if (scheduled.isAfter(DateTime.now())) {
                      await NotificationService.scheduleReminder(
                        id: serviceId,
                        vehicleNumber:
                            vehicle['vehicle_number'] ?? '',
                        serviceName: nameCtrl.text.trim(),
                        scheduledDateTime: scheduled,
                      );
                    }
                  } catch (e) {
                    debugPrint('Notification error: $e');
                  }
                }

                Navigator.pop(ctx);
                await _loadServices(vehicle['id'] as int);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── sheet scaffold ─────────────────────────────────────────────────────────
  Widget _sheetBody({
    required BuildContext ctx,
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: kBorder,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: kPrimary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: kTextDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          if (subtitle != null)
                            Text(subtitle,
                                style: const TextStyle(
                                    color: kTextMid, fontSize: 13)),
                        ]),
                  ]),
                  const SizedBox(height: 20),
                  ...children,
                ]),
          ),
        ),
      ),
    );
  }

  // ── field helpers ──────────────────────────────────────────────────────────
  Widget _tf(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
    TextCapitalization caps = TextCapitalization.words,
    Widget? prefix,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          textCapitalization: caps,
          maxLines: maxLines,
          style: const TextStyle(color: kTextDark, fontSize: 14),
          decoration: _inputDec(label, prefix: prefix),
        ),
      );

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label,
            style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      );

  Widget _serviceInputRow(
          Map<String, TextEditingController> row,
          VoidCallback onRemove) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: row['name'],
              style: const TextStyle(color: kTextDark, fontSize: 13),
              decoration: const InputDecoration(
                  hintText: 'Service name',
                  hintStyle: TextStyle(color: kTextMid, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true),
            ),
          ),
          Container(width: 1, height: 24, color: kBorder),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row['cost'],
              keyboardType: TextInputType.number,
              style: const TextStyle(color: kTextDark, fontSize: 13),
              decoration: const InputDecoration(
                  hintText: '₹ Cost',
                  hintStyle: TextStyle(color: kTextMid, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: kRed, size: 18),
          ),
        ]),
      );

  Widget _addRowButton(String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 44,
          decoration: BoxDecoration(
            border:
                Border.all(color: kPrimary, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_rounded, color: kPrimary, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: kPrimary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ── date picker ────────────────────────────────────────────────────────────
  Widget _datePicker({
    required BuildContext ctx,
    required DateTime? date,
    required ValueChanged<DateTime> onPicked,
    required VoidCallback onCleared,
    String label = 'Pick date (optional)',
    bool allowPast = false,
  }) =>
      GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: ctx,
            initialDate: date ??
                (allowPast
                    ? now
                    : now.add(const Duration(days: 7))),
            firstDate:
                allowPast ? DateTime(now.year - 10) : now,
            lastDate:
                DateTime.now().add(const Duration(days: 365 * 5)),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: kPrimary),
              ),
              child: child!,
            ),
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: date != null ? kPrimary : kBorder,
                width: date != null ? 1.8 : 1),
          ),
          child: Row(children: [
            Icon(Icons.calendar_month_rounded,
                color: date != null ? kPrimary : kTextMid, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date != null
                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                    : label,
                style: TextStyle(
                    color: date != null ? kTextDark : kTextMid,
                    fontSize: 14),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onCleared,
                child: const Icon(Icons.close_rounded,
                    color: kRed, size: 16),
              ),
          ]),
        ),
      );

  // ── time picker ────────────────────────────────────────────────────────────
  Widget _timePicker({
    required BuildContext ctx,
    required TimeOfDay? time,
    required ValueChanged<TimeOfDay> onPicked,
    required VoidCallback onCleared,
  }) =>
      GestureDetector(
        onTap: () async {
          final picked = await showTimePicker(
            context: ctx,
            initialTime:
                time ?? const TimeOfDay(hour: 9, minute: 0),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: kPrimary),
              ),
              child: child!,
            ),
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: time != null ? kPrimary : kBorder,
                width: time != null ? 1.8 : 1),
          ),
          child: Row(children: [
            Icon(Icons.access_time_rounded,
                color: time != null ? kPrimary : kTextMid, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                time != null
                    ? 'Remind at: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                    : 'Pick reminder time (default: 9:00 AM)',
                style: TextStyle(
                    color: time != null ? kTextDark : kTextMid,
                    fontSize: 14),
              ),
            ),
            if (time != null)
              GestureDetector(
                onTap: onCleared,
                child: const Icon(Icons.close_rounded,
                    color: kRed, size: 16),
              ),
          ]),
        ),
      );

  Widget _sheetButtons({
    required BuildContext ctx,
    required VoidCallback onSave,
    String saveLabel = 'Save',
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextMid,
                side: const BorderSide(color: kBorder),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(saveLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );

  // ── snackbar ───────────────────────────────────────────────────────────────
  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
}