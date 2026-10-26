import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smb_connect/smb_connect.dart';

import '../../core/config_sync_manager/config_sync_manager.dart';


class ArticleItem {
  final String name;
  final String fullPath;
  ArticleItem({required this.name, required this.fullPath});
}

// --- States ---
abstract class ArticleState {}
class ArticleInitial extends ArticleState {}
class ArticleLoading extends ArticleState {}
class ArticleLoaded extends ArticleState {
  final List<ArticleItem> articles;
  ArticleLoaded(this.articles);
}
class ArticleError extends ArticleState {
  final String message;
  ArticleError(this.message);
}

// --- Cubit ---
class ArticleCubit extends Cubit<ArticleState> {
  ArticleCubit() : super(ArticleInitial());

  List<ArticleItem> _allArticles = [];
  bool hasLoaded = false;

  Future<void> loadArticles({bool force = false}) async {
    if (hasLoaded && !force && _allArticles.isNotEmpty) {
      emit(ArticleLoaded(_allArticles));
      return;
    }

    emit(ArticleLoading());

    SmbConnect? connection;
    try {
      // 🚀 قراءة جميع المسارات وبيانات الاتصال عبر ConfigSyncManager
      final host = await ConfigSyncManager.getHost();
      final username = await ConfigSyncManager.getUsername();
      final password = await ConfigSyncManager.getPassword();
      final remoteFolderPath = await ConfigSyncManager.getArticleRemotePath();
      final targetSubfolders = await ConfigSyncManager.getArticleSubfolders();

      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: username,
        password: password,
      );

      final List<ArticleItem> found = [];
      // 🚀 مسح المجلدات بناءً على القائمة المجلوبة من الإكسل
      for (var sub in targetSubfolders) {
        await _scanFolderRecursive(connection, '$remoteFolderPath$sub', found);
      }

      _allArticles = found;
      hasLoaded = true;
      emit(ArticleLoaded(_allArticles));
      await connection.close();
    } catch (e) {
      emit(ArticleError('فشل في الاتصال أو مسح المجلدات: $e'));
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  Future<void> _scanFolderRecursive(SmbConnect connection, String folderPath, List<ArticleItem> results) async {
    try {
      final folderObj = await connection.file(folderPath);
      final List<SmbFile> items = await connection.listFiles(folderObj);

      for (var item in items) {
        final path = item.path;
        final name = path.split('/').last;

        if (item.isDirectory()) {
          await _scanFolderRecursive(connection, path, results);
        } else {
          final lower = name.toLowerCase();
          if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
            results.add(ArticleItem(name: name, fullPath: path));
          }
        }
      }
    } catch (e) {
      debugPrint('تم تخطي المجلد: $folderPath ($e)');
    }
  }
}