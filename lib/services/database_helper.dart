import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../constants/default_sheets.dart';
import '../constants/default_statuses.dart';

/// Accès SQLite. Le schéma reproduit à l'identique celui extrait de l'APK
/// d'origine (tables, colonnes, contraintes, index).
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<String> get dbPath async =>
      p.join(await getDatabasesPath(), AppConstants.dbName);

  Future<Database> _open() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Ferme la base (utile avant une restauration de sauvegarde).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// v2 : libellés/indicateurs des statuts par défaut alignés sur l'original, et
  /// fiche pédagogique par défaut si la bibliothèque est vide.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final d in kDefaultStatuses) {
        await db.update(
          'attendance_statuses',
          {
            'label_fr': d.labelFr,
            'label_ar': d.labelAr,
            'label_en': d.labelEn,
            'counts_as_absence': d.countsAsAbsence ? 1 : 0,
            'is_system': 1,
          },
          where: 'code = ?',
          whereArgs: [d.code],
        );
      }
      final n = (await db.rawQuery('SELECT COUNT(*) AS n FROM pedagogical_sheets')).first['n'] as int;
      if (n == 0) await _seedSheets(db);
    }
  }

  Future<void> _seedSheets(Database db) async {
    for (final s in kDefaultSheets) {
      await db.insert('pedagogical_sheets', {
        'title': s.title,
        'sport_discipline': s.discipline,
        'file_type': 'TEXT',
        'text_content': s.text.isEmpty ? null : s.text,
      });
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_years (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS terms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_year_id INTEGER NOT NULL,
        term_number INTEGER NOT NULL CHECK (term_number IN (1, 2, 3)),
        name TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        is_current INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (academic_year_id) REFERENCES academic_years (id) ON DELETE CASCADE,
        UNIQUE (academic_year_id, term_number)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_year_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        level TEXT NOT NULL,
        color_code TEXT DEFAULT '#1976D2',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (academic_year_id) REFERENCES academic_years (id) ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        gender TEXT CHECK (gender IN ('M', 'F')),
        student_number TEXT,
        is_exempt INTEGER NOT NULL DEFAULT 0,
        medical_reason TEXT,
        pai_conditions TEXT DEFAULT '',
        pai_instructions TEXT DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_statuses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        label_fr TEXT NOT NULL,
        label_ar TEXT NOT NULL,
        label_en TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        icon_name TEXT,
        counts_as_absence INTEGER NOT NULL DEFAULT 0,
        is_system INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pedagogical_sheets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        sport_discipline TEXT,
        file_type TEXT NOT NULL CHECK (file_type IN ('PDF', 'IMAGE', 'TEXT')),
        file_path TEXT,
        text_content TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        term_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        pedagogical_sheet_id INTEGER,
        status TEXT NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('COMPLETED', 'CANCELLED')),
        cancellation_reason TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE RESTRICT,
        FOREIGN KEY (pedagogical_sheet_id) REFERENCES pedagogical_sheets (id) ON DELETE SET NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        term_id INTEGER NOT NULL,
        status_id INTEGER NOT NULL,
        observation TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE RESTRICT,
        FOREIGN KEY (status_id) REFERENCES attendance_statuses (id) ON DELETE RESTRICT,
        UNIQUE (session_id, student_id)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS evaluations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        term_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        evaluation_date TEXT NOT NULL,
        max_score REAL NOT NULL DEFAULT 20.0,
        coefficient REAL NOT NULL DEFAULT 1.0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE RESTRICT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        evaluation_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        term_id INTEGER NOT NULL,
        score REAL CHECK (score >= 0 AND score <= 20),
        is_exempt INTEGER NOT NULL DEFAULT 0,
        status_code TEXT NOT NULL DEFAULT 'PRESENT',
        remarks TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (evaluation_id) REFERENCES evaluations (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE RESTRICT,
        UNIQUE (evaluation_id, student_id)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timetable_slots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_year_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        default_sheet_id INTEGER,
        field_name TEXT,
        FOREIGN KEY (academic_year_id) REFERENCES academic_years (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        FOREIGN KEY (default_sheet_id) REFERENCES pedagogical_sheets (id) ON DELETE SET NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incident_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        session_id INTEGER,
        incident_date TEXT NOT NULL,
        incident_time TEXT NOT NULL,
        location TEXT NOT NULL,
        activity TEXT,
        injury_type TEXT NOT NULL,
        injury_location TEXT,
        circumstances TEXT NOT NULL,
        first_aid_given TEXT,
        evacuation_type TEXT NOT NULL DEFAULT 'Infirmerie scolaire',
        witness_students TEXT,
        parent_contacted INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_attendances_session ON attendances(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attendances_student_term ON attendances(student_id, term_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_class ON incident_reports(class_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_student ON incident_reports(student_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_class_term_date ON sessions(class_id, term_id, session_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_student_grades_student_term ON student_grades(student_id, term_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_students_class_active ON students(class_id, is_active, sort_order)');

    await _seed(db);
    await _seedSheets(db);
  }

  /// Données initiales : statuts par défaut, année scolaire active et 3 trimestres.
  Future<void> _seed(Database db) async {
    var order = 0;
    for (final s in kDefaultStatuses) {
      await db.insert('attendance_statuses', {
        'code': s.code,
        'label_fr': s.labelFr,
        'label_ar': s.labelAr,
        'label_en': s.labelEn,
        'color_hex': s.colorHex,
        'icon_name': s.icon,
        'counts_as_absence': s.countsAsAbsence ? 1 : 0,
        'is_system': 1,
        'sort_order': order++,
      });
    }
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    final yearId = await db.insert('academic_years', {
      'name': '$startYear/${startYear + 1}',
      'is_active': 1,
    });
    const names = [
      '1er Trimestre (T1)',
      '2ème Trimestre (T2)',
      '3ème Trimestre (T3)',
    ];
    for (var i = 1; i <= 3; i++) {
      await db.insert('terms', {
        'academic_year_id': yearId,
        'term_number': i,
        'name': names[i - 1],
        'is_current': i == 1 ? 1 : 0,
        'is_locked': 0,
      });
    }
  }
}
