import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smb_connect/smb_connect.dart';

// 🚀 استدعاء مدير الإعدادات الديناميكي
import '../../core/config_sync_manager/config_sync_manager.dart';

class ExcelFileItem {
  final String name;
  final String fullPath;
  ExcelFileItem({required this.name, required this.fullPath});
}

// --- States ---
abstract class ExcelState {}
class ExcelInitial extends ExcelState {}
class ExcelLoading extends ExcelState {}
class ExcelLoaded extends ExcelState {
  final List<ExcelFileItem> files;
  ExcelLoaded(this.files);
}
class ExcelError extends ExcelState {
  final String message;
  ExcelError(this.message);
}

// --- Cubit ---
class ExcelCubit extends Cubit<ExcelState> {
  ExcelCubit() : super(ExcelInitial());

  List<ExcelFileItem> _allExcelFiles = [];
  bool hasLoaded = false;

  Future<void> loadExcelFiles({bool force = false}) async {
    if (hasLoaded && !force && _allExcelFiles.isNotEmpty) {
      emit(ExcelLoaded(_allExcelFiles));
      return;
    }

    // Clear cache if forced reload
    if (force) {
      hasLoaded = false;
      _allExcelFiles = [];
    }

    emit(ExcelLoading());

    SmbConnect? connection;
    try {
      // 🚀 قراءة بيانات الاتصال ومسارات مجلدات الإكسل ديناميكياً
      final host = await ConfigSyncManager.getHost();
      final username = await ConfigSyncManager.getUsername();
      final password = await ConfigSyncManager.getPassword();
      final remoteFolderPath = await ConfigSyncManager.getExcelRemotePath();
      final targetSubfolders = await ConfigSyncManager.getExcelSubfolders();

      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: username,
        password: password,
      );

      final List<ExcelFileItem> foundFiles = [];

      // 🚀 مسح المجلدات بناءً على القائمة المجلوبة من ملف الإعدادات
      for (var sub in targetSubfolders) {
        final cleanMain = remoteFolderPath.replaceAll(RegExp(r'/$'), '');
        final cleanSub = sub.startsWith('/') ? sub : '/$sub';
        final fullFolderPath = '$cleanMain$cleanSub';

        await _scanFolderForExcelRecursive(connection, fullFolderPath, foundFiles);
      }

      _allExcelFiles = foundFiles;
      hasLoaded = true;
      emit(ExcelLoaded(_allExcelFiles));
      await connection.close();
    } catch (e) {
      emit(ExcelError('فشل في الاتصال أو مسح ملفات الإكسل: $e'));
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  Future<void> _scanFolderForExcelRecursive(SmbConnect connection, String folderPath, List<ExcelFileItem> results) async {
    try {
      final folderObj = await connection.file(folderPath);
      final List<SmbFile> items = await connection.listFiles(folderObj);

      for (var item in items) {
        final path = item.path;
        final name = path.split('/').last;

        if (item.isDirectory()) {
          await _scanFolderForExcelRecursive(connection, path, results);
        } else {
          final lower = name.toLowerCase();
          if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
            results.add(ExcelFileItem(name: name, fullPath: path));
          }
        }
      }
    } catch (e) {
      debugPrint('تم تخطي المجلد: $folderPath ($e)');
    }
  }
}