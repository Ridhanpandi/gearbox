import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('garage.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          try { await db.execute('ALTER TABLE vehicles ADD COLUMN reminder_note TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE vehicles ADD COLUMN reminder_date TEXT DEFAULT ""'); } catch (_) {}
        }
        if (oldVersion < 4) {
          await db.execute('DROP TABLE IF EXISTS stock');
          await db.execute('''
            CREATE TABLE stock (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              part_name    TEXT NOT NULL,
              part_brand   TEXT DEFAULT "",
              part_model   TEXT DEFAULT "",
              part_number  TEXT DEFAULT "",
              quantity     INTEGER DEFAULT 0,
              created_at   TEXT DEFAULT (datetime('now'))
            )
          ''');
        }
        if (oldVersion < 5) {
          try { await db.execute('ALTER TABLE vehicles ADD COLUMN reminder_time TEXT DEFAULT ""'); } catch (_) {}
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_number TEXT UNIQUE NOT NULL COLLATE NOCASE,
        owner_name     TEXT,
        phone          TEXT,
        make           TEXT,
        model          TEXT,
        year           TEXT,
        reminder_note  TEXT DEFAULT "",
        reminder_date  TEXT DEFAULT "",
        reminder_time  TEXT DEFAULT "",
        created_at     TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE services (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id        INTEGER NOT NULL,
        service_name      TEXT NOT NULL,
        description       TEXT,
        cost              REAL DEFAULT 0,
        service_date      TEXT,
        next_service_date TEXT,
        status            TEXT DEFAULT 'completed',
        created_at        TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE stock (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        part_name    TEXT NOT NULL,
        part_brand   TEXT DEFAULT "",
        part_model   TEXT DEFAULT "",
        part_number  TEXT DEFAULT "",
        quantity     INTEGER DEFAULT 0,
        created_at   TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  // ── Vehicles ──────────────────────────────────────────────
  Future<int> insertVehicle(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      'vehicles',
      data,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<int> updateVehicle(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'vehicles',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getVehicleByNumber(String number) async {
    final db = await database;
    final result = await db.query(
      'vehicles',
      where: 'vehicle_number = ?',
      whereArgs: [number.trim().toUpperCase()],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    final db = await database;
    return await db.query('vehicles', orderBy: 'created_at DESC');
  }

  Future<void> deleteVehicle(int id) async {
    final db = await database;
    await db.delete('services', where: 'vehicle_id = ?', whereArgs: [id]);
    await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  // ── Services ──────────────────────────────────────────────
  Future<int> insertService(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('services', data);
  }

  Future<List<Map<String, dynamic>>> getServicesByVehicle(int vehicleId) async {
    final db = await database;
    return await db.query(
      'services',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'service_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingServices() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.*, v.vehicle_number, v.owner_name, v.phone
      FROM services s
      JOIN vehicles v ON s.vehicle_id = v.id
      WHERE s.next_service_date IS NOT NULL
        AND s.next_service_date != ''
        AND date(s.next_service_date) <= date('now', '+2 days')
        AND date(s.next_service_date) >= date('now')
      ORDER BY s.next_service_date ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getVehicleReminders() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        id,
        vehicle_number,
        owner_name,
        phone,
        reminder_date  AS next_service_date,
        reminder_time  AS reminder_time,
        reminder_note  AS service_name,
        ""             AS description,
        ""             AS status
      FROM vehicles
      WHERE reminder_date IS NOT NULL
        AND reminder_date != ""
        AND date(reminder_date) >= date('now')
      ORDER BY reminder_date ASC
    ''');
  }

  Future<void> deleteService(int id) async {
    final db = await database;
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  // ── Stock ─────────────────────────────────────────────────
  Future<int> insertStock(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('stock', data);
  }

  Future<List<Map<String, dynamic>>> getAllStock() async {
    final db = await database;
    return await db.query('stock', orderBy: 'part_name ASC');
  }

  Future<void> updateStockQty(int id, int qty) async {
    final db = await database;
    await db.update(
      'stock',
      {'quantity': qty},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStock(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'stock',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteStock(int id) async {
    final db = await database;
    await db.delete('stock', where: 'id = ?', whereArgs: [id]);
  }
}