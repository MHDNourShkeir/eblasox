import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config_sync_manager/config_sync_manager.dart';
import '../article_image/article_cubit.dart';
import '../excel_search_screen/excel_viewer_cubit.dart';

// States
abstract class ManagementState {}
class ManagementInitial extends ManagementState {}
class ManagementLoading extends ManagementState {}
class ManagementLoaded extends ManagementState {
  final String host;
  final String username;
  final String password;
  final String remoteFolderPath;
  final List<String> targetSubfolders;
  final String excelRemoteFolderPath;
  final List<String> excelTargetSubfolders;
  final String adminPassword;

  ManagementLoaded({
    required this.host,
    required this.username,
    required this.password,
    required this.remoteFolderPath,
    required this.targetSubfolders,
    required this.excelRemoteFolderPath,
    required this.excelTargetSubfolders,
    required this.adminPassword,
  });
}
class ManagementSaved extends ManagementState {}
class ManagementError extends ManagementState {
  final String message;
  ManagementError(this.message);
}

// Cubit
class ManagementCubit extends Cubit<ManagementState> {
  ManagementCubit() : super(ManagementInitial());

  Future<void> loadSettings() async {
    emit(ManagementLoading());
    try {
      // 🚀 جلب البيانات ديناميكياً بدلاً من AppConfig
      final host = await ConfigSyncManager.getHost();
      final username = await ConfigSyncManager.getUsername();
      final password = await ConfigSyncManager.getPassword();

      final remoteFolderPath = await ConfigSyncManager.getArticleRemotePath();
      final targetSubfolders = await ConfigSyncManager.getArticleSubfolders();

      final excelRemoteFolderPath = await ConfigSyncManager.getExcelRemotePath();
      final excelTargetSubfolders = await ConfigSyncManager.getExcelSubfolders();

      final adminPassword = await ConfigSyncManager.getAdminPassword();

      emit(ManagementLoaded(
        host: host,
        username: username,
        password: password,
        remoteFolderPath: remoteFolderPath,
        targetSubfolders: targetSubfolders,
        excelRemoteFolderPath: excelRemoteFolderPath,
        excelTargetSubfolders: excelTargetSubfolders,
        adminPassword: adminPassword,
      ));
    } catch (e) {
      emit(ManagementError('فشل في تحميل الإعدادات: $e'));
    }
  }

  Future<void> saveSettings({
    required String host,
    required String username,
    required String password,
    required String remoteFolderPath,
    required String subfoldersText,
    required String excelRemoteFolderPath,
    required String excelSubfoldersText,
    required String adminPassword,
    required BuildContext context,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🚀 حفظ التعديلات المحلية باستخدام المفاتيح المتوافقة تماماً مع ConfigSyncManager
      await prefs.setString('host', host.trim());
      await prefs.setString('username', username.trim());
      await prefs.setString('password', password.trim());

      await prefs.setString('article_remote_path', remoteFolderPath.trim());
      final subs = subfoldersText
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await prefs.setStringList('article_subfolders', subs);

      await prefs.setString('excel_remote_path', excelRemoteFolderPath.trim());
      final excelSubsList = excelSubfoldersText
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await prefs.setStringList('excel_subfolders', excelSubsList);

      if (adminPassword.trim().isNotEmpty) {
        await prefs.setString('admin_password', adminPassword.trim());
      }

      // Refresh data across the app using central cubits
      if (context.mounted) {
        context.read<ArticleCubit>().loadArticles(force: true);
        context.read<ExcelCubit>().loadExcelFiles(force: true);
      }

      emit(ManagementSaved());
    } catch (e) {
      emit(ManagementError('فشل في حفظ الإعدادات: $e'));
    }
  }
}