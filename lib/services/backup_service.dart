import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

/// 数据库备份与恢复服务（zip 压缩包）
class BackupService {
  BackupService._();

  static const String _dbFileName = 'smart_ledger.db';

  /// 备份：
  /// 1. 先执行 WAL 检查点，确保内存/日志中的数据全部落盘
  /// 2. 让用户选择保存目录（Windows 下可在文档/任意位置，Android 下为下载等目录）
  /// 3. 将数据库文件压缩为 .zip 写入所选目录
  ///
  /// 返回 zip 文件完整路径；用户取消返回空字符串。
  static Future<String> backupDatabase() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择备份保存目录',
    );
    if (dir == null) return '';

    // 刷写 WAL，保证备份文件包含最新数据
    await DatabaseService.instance.checkpoint();
    final dbFile = await _dbFile();
    final bytes = await dbFile.readAsBytes();

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final zipPath = p.join(dir, 'smart_ledger_backup_$stamp.zip');

    final archive = Archive()
      ..addFile(ArchiveFile(_dbFileName, bytes.length, bytes));
    final zipBytes = ZipEncoder().encode(archive)!;
    await File(zipPath).writeAsBytes(zipBytes, flush: true);
    return zipPath;
  }

  /// 恢复：
  /// 1. 用户从文件管理器选取备份 zip
  /// 2. 解压出 .db 文件，覆盖当前数据库（先关闭连接并清理 -wal/-shm）
  /// 3. 返回恢复的字节数（-1 表示用户取消）；调用方负责刷新 UI 状态
  static Future<int> restoreDatabase() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
      dialogTitle: '选择备份文件',
    );
    final file = picked?.files.single;
    if (file == null) return -1;

    final bytes =
        file.bytes ?? await File(file.path!).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (entry.name != _dbFileName && !entry.name.endsWith('.db')) continue;

      final dbBytes = entry.content as List<int>;
      await DatabaseService.instance.closeForRestore();
      final target = await _dbFile();
      await target.writeAsBytes(dbBytes, flush: true);
      return dbBytes.length;
    }
    throw const FormatException('备份包中未找到数据库文件（*.db）');
  }

  static Future<File> _dbFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _dbFileName));
  }
}
