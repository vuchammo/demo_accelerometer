import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../chart_data_point.dart';
import 'recording_session.dart';

/// Singleton database cho lưu trữ phiên ghi
class RecordingDatabase {
  RecordingDatabase._();
  static final RecordingDatabase instance = RecordingDatabase._();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'motion_recordings.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recording_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        total_samples INTEGER NOT NULL,
        avg_magnitude REAL NOT NULL,
        motion_percentage REAL NOT NULL,
        label TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE recording_data_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        relative_time REAL NOT NULL,
        magnitude REAL NOT NULL,
        category TEXT NOT NULL,
        is_moving INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES recording_sessions(id) ON DELETE CASCADE
      )
    ''');

    // Index cho query nhanh
    await db.execute(
      'CREATE INDEX idx_data_points_session ON recording_data_points(session_id)',
    );
  }

  /// Lưu phiên ghi mới, trả về session id
  Future<int> insertSession(RecordingSession session) async {
    final db = await database;
    return db.insert('recording_sessions', session.toMap());
  }

  /// Lưu batch data points cho một session
  Future<void> insertDataPoints(
    int sessionId,
    List<ChartDataPoint> dataPoints,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final point in dataPoints) {
      batch.insert('recording_data_points', point.toMap(sessionId));
    }
    await batch.commit(noResult: true);
  }

  /// Lấy tất cả sessions, sắp xếp mới nhất trước
  Future<List<RecordingSession>> getAllSessions() async {
    final db = await database;
    final maps = await db.query(
      'recording_sessions',
      orderBy: 'start_time DESC',
    );
    return maps.map((m) => RecordingSession.fromMap(m)).toList();
  }

  /// Lấy data points của một session
  Future<List<ChartDataPoint>> getSessionDataPoints(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'recording_data_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'relative_time ASC',
    );
    return maps.map((m) => ChartDataPoint.fromMap(m)).toList();
  }

  /// Xóa một session và data points liên quan
  Future<void> deleteSession(int sessionId) async {
    final db = await database;
    await db.delete(
      'recording_data_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      'recording_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Xóa tất cả sessions
  Future<void> deleteAllSessions() async {
    final db = await database;
    await db.delete('recording_data_points');
    await db.delete('recording_sessions');
  }
}
