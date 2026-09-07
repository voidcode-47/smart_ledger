import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;

import '../models/category_model.dart';
import '../models/transaction_model.dart';

/// SQLite 数据访问层
/// - Android/iOS：使用系统 sqflite 插件
/// - Windows/Linux：通过 sqflite_common_ffi (SQLite FFI) 支持
/// - v2：新增 categories 表（用户可自定义分类），transactions.category 存分类名称
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const String _dbName = 'smart_ledger.db';
  static const int _dbVersion = 3;
  static const String _table = 'transactions';
  static const String _catTable = 'categories';
  static const String _budgetTable = 'budgets';

  /// 兜底分类名：删除自定义分类时，其流水迁移到这里；该分类禁止删除。
  static const String fallbackCategoryName = '其他';

  Database? _db;

  Future<Database> get database async {
    final db = _db;
    if (db != null && db.isOpen) return db;
    return _db = await _open();
  }

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbName);

    if (Platform.isWindows || Platform.isLinux) {
      sqflite_ffi.sqfliteFfiInit();
      return sqflite_ffi.databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==================== Schema ====================

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        isIncome INTEGER NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_${_table}_createdAt ON $_table(createdAt)');
    await _createCategories(db);
    await _seedDefaultCategories(db);
    await _createBudgets(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2：新增分类表，并把旧枚举分类名迁移为默认中文名
    if (oldVersion < 2) {
      await _createCategories(db);
      await _seedDefaultCategories(db);
      await db.execute(
          "UPDATE $_table SET category = '餐饮' WHERE category = 'food'");
      await db.execute(
          "UPDATE $_table SET category = '购物' WHERE category = 'shopping'");
      await db.execute(
          "UPDATE $_table SET category = '交通' WHERE category = 'transport'");
      await db.execute(
          "UPDATE $_table SET category = '娱乐' WHERE category = 'entertainment'");
      await db.execute(
          "UPDATE $_table SET category = '其他' WHERE category = 'other'");
    }
    // v2 -> v3：新增月度预算表
    if (oldVersion < 3) {
      await _createBudgets(db);
    }
  }

  Future<void> _createBudgets(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_budgetTable (
        month TEXT PRIMARY KEY,
        amount REAL NOT NULL
      )
    ''');
  }

  Future<void> _createCategories(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_catTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        isIncome INTEGER NOT NULL,
        isSystem INTEGER NOT NULL,
        sortOrder INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    await db.execute('''
      INSERT OR IGNORE INTO $_catTable (name, icon, color, isIncome, isSystem, sortOrder) VALUES
        ('餐饮', 'restaurant', 0xFFF6AD55, 0, 1, 0),
        ('购物', 'shopping',   0xFF63B3ED, 0, 1, 1),
        ('交通', 'transport',  0xFF68D391, 0, 1, 2),
        ('娱乐', 'entertainment', 0xFFF687B3, 0, 1, 3),
        ('其他', 'other',      0xFFB794F4, 0, 1, 4),
        ('收入', 'income',     0xFF4ADE80, 1, 1, 0)
    ''');
  }

  /// 启动时调用：打开数据库并返回当前版本号。
  Future<int> ensureSchema() async {
    final db = await database;
    final rows = await db.rawQuery('PRAGMA user_version');
    return (rows.first['user_version'] as int?) ?? 0;
  }

  /// 执行 WAL 检查点，把日志中的数据刷入主数据库文件（备份前调用）
  Future<void> checkpoint() async {
    final db = await database;
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// 关闭数据库连接并删除 -wal/-shm 附属文件（恢复备份覆盖文件前调用）
  Future<void> closeForRestore() async {
    final db = _db;
    _db = null;
    await db?.close();

    final dir = await getApplicationSupportDirectory();
    for (final suffix in const ['-wal', '-shm']) {
      final f = File(p.join(dir.path, '$_dbName$suffix'));
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  // ==================== 流水 CRUD ====================

  Future<int> insert(TransactionEntry entry) async {
    final db = await database;
    return db.insert(_table, entry.toDbMap());
  }

  /// 批量导入（CSV 恢复用）
  Future<void> insertAll(List<TransactionEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final e in entries) {
      batch.insert(_table, e.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<int> update(int id, TransactionEntry entry) async {
    final db = await database;
    return db.update(_table, entry.toDbMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 全量流水，按时间倒序
  Future<List<TransactionEntry>> listAll() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'createdAt DESC, id DESC');
    return rows.map(TransactionEntry.fromDbMap).toList();
  }

  // ==================== 分类 CRUD ====================

  /// 全部分类（支出在前，按 sortOrder 排序）
  Future<List<Category>> listCategories() async {
    final db = await database;
    final rows = await db.query(
      _catTable,
      orderBy: 'isIncome ASC, sortOrder ASC, id ASC',
    );
    return rows.map(Category.fromDbMap).toList();
  }

  /// 新增自定义分类。重名时抛异常（name UNIQUE）。
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return db.insert(_catTable, category.toDbMap());
  }

  /// 更新分类（可改名 / 换图标 / 换颜色）。
  /// 若名称变化，会同步更新所有引用了旧名称的流水记录（同一事务）。
  /// 兜底分类“其他”不可改名（保证删除迁移始终有归宿），其余分类（含内置）均可改名。
  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(_catTable,
          columns: ['name'], where: 'id = ?', whereArgs: [category.id]);
      final oldName = rows.isEmpty ? null : rows.first['name'] as String;
      if (oldName == null) return;

      if (oldName == fallbackCategoryName) {
        // 兜底分类：仅允许换图标颜色
        await txn.update(
          _catTable,
          {'icon': category.icon, 'color': category.color},
          where: 'id = ?',
          whereArgs: [category.id],
        );
      } else {
        await txn.update(
          _catTable,
          {
            'name': category.name,
            'icon': category.icon,
            'color': category.color,
          },
          where: 'id = ?',
          whereArgs: [category.id],
        );
        if (oldName != category.name) {
          await txn.update(
            _table,
            {'category': category.name},
            where: 'category = ?',
            whereArgs: [oldName],
          );
        }
      }
    });
  }

  /// 删除自定义分类：其下流水迁移到兜底分类“其他”，再删除分类行。
  /// 内置分类与兜底分类禁止删除，返回 false。
  Future<bool> deleteCategory(int id) async {
    final db = await database;
    var deleted = false;
    await db.transaction((txn) async {
      final rows = await txn.query(_catTable,
          columns: ['name', 'isSystem'],
          where: 'id = ?',
          whereArgs: [id]);
      if (rows.isEmpty) return;
      final name = rows.first['name'] as String;
      final isSystem = (rows.first['isSystem'] as int) == 1;
      if (isSystem || name == fallbackCategoryName) return;
      await txn.update(
        _table,
        {'category': fallbackCategoryName},
        where: 'category = ?',
        whereArgs: [name],
      );
      await txn.delete(_catTable, where: 'id = ?', whereArgs: [id]);
      deleted = true;
    });
    return deleted;
  }

  // ==================== 月度预算 ====================

  /// 查询某月预算（month 格式 'yyyy-MM'）；未设置返回 null
  Future<double?> getBudget(String month) async {
    final db = await database;
    final rows = await db.query(_budgetTable,
        columns: ['amount'], where: 'month = ?', whereArgs: [month]);
    if (rows.isEmpty) return null;
    return (rows.first['amount'] as num).toDouble();
  }

  /// 设置（或清除，amount <= 0 视为清除）某月预算
  Future<void> setBudget(String month, double amount) async {
    final db = await database;
    if (amount <= 0) {
      await db.delete(_budgetTable, where: 'month = ?', whereArgs: [month]);
      return;
    }
    await db.insert(_budgetTable, {'month': month, 'amount': amount},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
