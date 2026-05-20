import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const kPrimary   = Color(0xFFFF4D00);
const kPrimaryDk = Color(0xFFFF4D00);
const kBg = Color(0xFFFFDAB9);
const kCard      = Color(0xFFFFFFFF);
const kTextDark  = Color(0xFF1A1A2E);
const kTextMid   = Color(0xFF6B7280);
const kBorder    = Color(0xFFE5E7EB);
const kGreen     = Color(0xFF22C55E);
const kRed       = Color(0xFFFF4D00);

// ── Shared input decoration ───────────────────────────────────────────────────
InputDecoration _inputDec(String label, {Widget? prefix}) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kTextMid, fontSize: 14),
      prefixIcon: prefix,
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

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with SingleTickerProviderStateMixin {
  final db = FirestoreService.instance;
  List<Map<String, dynamic>> stock = [];
  final searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    loadStock();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> loadStock() async {
    final list = await db.getAllStock();
    setState(() => stock = list);
    _fadeCtrl.forward(from: 0);
  }

  List<Map<String, dynamic>> get filtered {
    final q = searchCtrl.text.toLowerCase();
    if (q.isEmpty) return stock;
    return stock
        .where((s) =>
            (s['part_name']   ?? '').toLowerCase().contains(q) ||
            (s['part_number'] ?? '').toLowerCase().contains(q) ||
            (s['part_model']  ?? '').toLowerCase().contains(q) ||
            (s['part_brand']  ?? '').toLowerCase().contains(q))
        .toList();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddPart,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Part',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── gradient header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Stock Inventory',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Manage your parts & quantities',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ── search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: TextField(
          controller: searchCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: kTextDark, fontSize: 14),
          decoration: _inputDec('Search by name, brand, model or number…',
              prefix:
                  const Icon(Icons.search_rounded, color: kTextMid, size: 20)),
        ),
      );

  // ── body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (filtered.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: loadStock,
      color: kPrimary,
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _StockCard(
            part: filtered[i],
            onEdit: () => showEditPart(filtered[i]),
            onDelete: () => _confirmDelete(filtered[i]['id']),
            onQtyChange: (newQty) async {
               await db.updateStockQty(filtered[i]['id'], newQty);
               final updated = await db.getAllStock();
               setState(() => stock = updated);
            },
          ),
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
                color: kPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: kPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            stock.isEmpty ? 'No parts yet' : 'No results found',
            style: const TextStyle(
                color: kTextDark, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            stock.isEmpty
                ? 'Tap + to add your first part'
                : 'Try a different search term',
            style: const TextStyle(color: kTextMid, fontSize: 14),
          ),
        ]),
      );

  // ── ADD PART SHEET ─────────────────────────────────────────────────────────
  void showAddPart() {
    final nameCtrl   = TextEditingController();
    final modelCtrl  = TextEditingController();
    final numberCtrl = TextEditingController();
    final brandCtrl  = TextEditingController();
    final qtyCtrl    = TextEditingController(text: '0');

    _showSheet(
      title: 'Add Part',
      icon: Icons.add_box_outlined,
      fields: [nameCtrl, modelCtrl, numberCtrl, brandCtrl, qtyCtrl],
      onSave: () async {
        if (nameCtrl.text.trim().isEmpty) return;
        await db.insertStock({
          'part_name'  : nameCtrl.text.trim(),
          'part_brand' : brandCtrl.text.trim(),
          'part_model' : modelCtrl.text.trim(),
          'part_number': numberCtrl.text.trim().toUpperCase(),
          // FIX: always parse as int, default 0
          'quantity'   : int.tryParse(qtyCtrl.text.trim()) ?? 0,
        });
        loadStock();
        _snack('Part added!', kGreen);
      },
    );
  }

  // ── EDIT PART SHEET ────────────────────────────────────────────────────────
  void showEditPart(Map<String, dynamic> part) {
    final nameCtrl   = TextEditingController(text: part['part_name']   ?? '');
    final modelCtrl  = TextEditingController(text: part['part_model']  ?? '');
    final numberCtrl = TextEditingController(text: part['part_number'] ?? '');
    final brandCtrl  = TextEditingController(text: part['part_brand']  ?? '');
    // FIX: convert quantity to int first before toString to avoid '9' string issues
    final qtyCtrl    = TextEditingController(
        text: '${(part['quantity'] is int ? part['quantity'] : int.tryParse('${part['quantity']}') ?? 0)}');

    _showSheet(
      title: 'Edit Part',
      icon: Icons.edit_outlined,
      fields: [nameCtrl, modelCtrl, numberCtrl, brandCtrl, qtyCtrl],
      saveLabel: 'Update',
      onSave: () async {
        if (nameCtrl.text.trim().isEmpty) return;
        await db.updateStock(part['id'], {
          'part_name'  : nameCtrl.text.trim(),
          'part_brand' : brandCtrl.text.trim(),
          'part_model' : modelCtrl.text.trim(),
          'part_number': numberCtrl.text.trim().toUpperCase(),
          // FIX: always parse as int, default 0
          'quantity'   : int.tryParse(qtyCtrl.text.trim()) ?? 0,
        });
        loadStock();
        _snack('Part updated!', kGreen);
      },
    );
  }

  // ── generic sheet builder ──────────────────────────────────────────────────
  void _showSheet({
    required String title,
    required IconData icon,
    required List<TextEditingController> fields,
    required VoidCallback onSave,
    String saveLabel = 'Save',
  }) {
    final labels = [
      'Part Name *',
      'Part Model',
      'Part Number',
      'Part Brand',
      'Quantity in Stock',
    ];
    final keyboards = [
      TextInputType.text,
      TextInputType.text,
      TextInputType.text,
      TextInputType.text,
      TextInputType.number,
    ];
    final caps = [
      TextCapitalization.words,
      TextCapitalization.words,
      TextCapitalization.characters,
      TextCapitalization.words,
      TextCapitalization.none,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ClipRRect(
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
                    // drag handle
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

                    // title row
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
                      Text(title,
                          style: const TextStyle(
                              color: kTextDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 20),

                    // fields
                    ...List.generate(
                      fields.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextField(
                          controller: fields[i],
                          keyboardType: keyboards[i],
                          textCapitalization: caps[i],
                          style: const TextStyle(color: kTextDark, fontSize: 14),
                          decoration: _inputDec(labels[i]),
                        ),
                      ),
                    ),

                    // buttons
                    Row(children: [
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
                          onPressed: () {
                            Navigator.pop(ctx);
                            onSave();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(saveLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── delete confirm ─────────────────────────────────────────────────────────
  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Part',
            style:
                TextStyle(color: kTextDark, fontWeight: FontWeight.w800)),
        content: const Text('Remove this part from inventory?',
            style: TextStyle(color: kTextMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: kTextMid, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await db.deleteStock(id);
              loadStock();
              _snack('Part deleted.', kRed);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

// ── Stock Card ────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.part,
    required this.onEdit,
    required this.onDelete,
    required this.onQtyChange,
  });

  final Map<String, dynamic> part;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(int) onQtyChange;

  @override
  Widget build(BuildContext context) {
    // FIX: safely parse quantity as int regardless of whether DB returns
    // int or String — this is the root cause of the "max 9" bug.
    final qty = part['quantity'] is int
        ? part['quantity'] as int
        : int.tryParse('${part['quantity'] ?? 0}') ?? 0;

    final isOut = qty == 0;
    final qtyColor = isOut ? kRed : kGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // top strip
        Container(
          height: 5,
          decoration: const BoxDecoration(
            color: kBorder,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── left: part info ──────────────────────────────────────────
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(part['part_name'] ?? '',
                        style: const TextStyle(
                            color: kTextDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    if ((part['part_brand'] ?? '').isNotEmpty)
                      _infoRow(Icons.storefront_outlined, 'Brand',
                          part['part_brand']),
                    if ((part['part_model'] ?? '').isNotEmpty)
                      _infoRow(Icons.build_circle_outlined, 'Model',
                          part['part_model']),
                    if ((part['part_number'] ?? '').isNotEmpty)
                      _infoRow(Icons.tag_rounded, 'Part #',
                          part['part_number']),

                    const SizedBox(height: 12),

                    // edit / delete row
                    Row(children: [
                      _actionBtn(
                          Icons.edit_outlined, kPrimary, 'Edit', onEdit),
                      const SizedBox(width: 8),
                      _actionBtn(
                          Icons.delete_outline, kRed, 'Delete', onDelete),
                    ]),
                  ]),
            ),

            const SizedBox(width: 16),

            // ── right: qty display + stepper ────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // qty pill — widened to fit multi-digit numbers
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: qtyColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: qtyColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Text('$qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: qtyColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    Text(isOut ? 'out' : 'in stock',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: qtyColor, fontSize: 10)),
                  ]),
                ),

                const SizedBox(height: 10),

                // FIX: stepper wrapped in SizedBox so both buttons always
                // have enough room and neither gets clipped.
                // Minus button hidden when qty == 0, shown when qty > 0.
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (qty > 0) ...[
                        _stepBtn(Icons.remove_rounded, qtyColor, () {
                          onQtyChange(qty - 1);
                        }),
                        const SizedBox(width: 8),
                      ],
                      _stepBtn(Icons.add_rounded, kPrimary, () {
                        onQtyChange(qty + 1);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 13, color: kTextMid),
          const SizedBox(width: 5),
          Text('$label: ',
              style: const TextStyle(color: kTextMid, fontSize: 12)),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    color: kTextDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Widget _actionBtn(
          IconData icon, Color color, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _stepBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}