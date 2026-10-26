import 'package:excel/excel.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smb_connect/smb_connect.dart';

// ==========================================
// 1. القيم الافتراضية (Fallback Configuration)
// ==========================================
class AppConfig {
  static const String defaultHost = '192.168.1.250';
  static const String defaultUsername = 'MCH5';
  static const String defaultPassword = '12345600';

  static const String defaultArticleRemotePath = '/Privet/Catalog/EblaSox';
  static const List<String> defaultArticleSubfolders = [
    '/DUKE/basic',
    '/DUKE/winter 2027',
    '/DUKE/summer 2026',
    '/sales/basic 2027',
    '/sales/sales summer 2027',
    '/sales/sales winter 2027',
    '/sales/AI presentation 2026',
  ];

  static const String defaultExcelRemotePath = '/Public';
  static const List<String> defaultExcelSubfolders = [
    '/orders 2026',
    '/orders 2025',
  ];

  static const String defaultAdminPassword = 'ts2yn2oy2';

  static const String defaultConfigFilePath = '/Public/البرمجة الجديدة/CONFIG/config.xlsx';
  static const String defaultAdvancesFilePath = '/Public/البرمجة الجديدة/CONFIG/سلف.xlsx';
}

// ==========================================
// 2. مدير المزامنة (Config Sync Manager)
// ==========================================
class ConfigSyncManager {

  /// قم بتمرير ملف الـ config.xlsx بعد جلبه من السيرفر إلى هذه الدالة
  static Future<void> syncConfigWithServer(
      List<int> fileBytes, {
        bool clearSessionOnUpdate = true,
      }) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      var excel = Excel.decodeBytes(fileBytes);
      var sheet = excel.tables['App_Settings'];

      if (sheet != null) {
        Map<String, dynamic> excelData = {};

        // قراءة المتغيرات من الإكسل
        for (var row in sheet.rows) {
          if (row.isEmpty || row[0]?.value == null) continue;

          String key = row[0]!.value.toString().trim();

          if (key == 'article_subfolders' || key == 'excel_subfolders') {
            List<String> folders = [];
            for (int i = 1; i < row.length; i++) {
              if (row[i]?.value != null && row[i]!.value.toString().trim().isNotEmpty) {
                folders.add(row[i]!.value.toString().trim());
              }
            }
            excelData[key] = folders;
          } else if (row.length >= 2 && row[1]?.value != null) {
            excelData[key] = row[1]!.value.toString().trim();
          }
        }

        // 🚀 1. معالجة آمنة لرقم الإصدار القادم من السيرفر (لتجاهل فواصل الإكسل مثل 1.0)
        String rawVersion = excelData['version']?.toString() ?? '0';
        int remoteVersion = double.tryParse(rawVersion)?.toInt() ?? 0;

        // 🚀 2. معالجة آمنة للإصدار المحلي (لمنع انهيار التطبيق إذا كان محفوظاً بشكل خاطئ)
        int localVersion = 0;
        try {
          localVersion = prefs.getInt('config_version') ?? 0;
        } catch (e) {
          // إذا كان محفوظاً كنص بالخطأ في تجارب سابقة
          localVersion = int.tryParse(prefs.getString('config_version') ?? '0') ?? 0;
        }

        debugPrint('🔍 الإصدار المحلي: $localVersion | إصدار السيرفر: $remoteVersion');

        // مقارنة الإصدارات
        if (remoteVersion != localVersion && remoteVersion > 0) {
          // تم اكتشاف تحديث جديد!
          await prefs.setInt('config_version', remoteVersion);

          if (excelData.containsKey('host')) await prefs.setString('host', excelData['host']);
          if (excelData.containsKey('username')) await prefs.setString('username', excelData['username']);
          if (excelData.containsKey('password')) await prefs.setString('password', excelData['password']);
          if (excelData.containsKey('admin_password')) await prefs.setString('admin_password', excelData['admin_password']);
          if (excelData.containsKey('article_remote_path')) await prefs.setString('article_remote_path', excelData['article_remote_path']);
          if (excelData.containsKey('excel_remote_path')) await prefs.setString('excel_remote_path', excelData['excel_remote_path']);
          if (excelData.containsKey('config_file_path')) await prefs.setString('config_file_path', excelData['config_file_path']);
          if (excelData.containsKey('advances_file_path')) await prefs.setString('advances_file_path', excelData['advances_file_path']);

          if (excelData.containsKey('article_subfolders')) {
            await prefs.setStringList('article_subfolders', List<String>.from(excelData['article_subfolders']));
          }
          if (excelData.containsKey('excel_subfolders')) {
            await prefs.setStringList('excel_subfolders', List<String>.from(excelData['excel_subfolders']));
          }

          // 🚀 3. مسح جلسة الدخول فقط إذا طُلب ذلك (عند فتح التطبيق وليس بعد تسجيل الدخول)
          if (clearSessionOnUpdate) {
            debugPrint('⚠️ تم مسح جلسة تسجيل الدخول بسبب تغير رقم الإصدار!');
            // تأكد أن 'loggedInUser' هو نفس المفتاح الذي تستخدمه في AuthCubit لحفظ اسم المستخدم
            await prefs.remove('loggedInUser');
          }

        } else {
          debugPrint('✅ الإعدادات متطابقة. لا داعي لمسح جلسة تسجيل الدخول.');
        }
      } else {
        debugPrint('⚠️ ورقة "App_Settings" غير موجودة.');
      }
    } catch (e) {
      debugPrint('⚠️ فشل مزامنة الإعدادات: $e');
    }
  }

  // 🚀 دالة شاملة تتصل بالسيرفر وتجلب الملف وتحدث الإعدادات
  static Future<void> fetchAndSyncFromServer({bool clearSessionOnUpdate = true}) async {
    SmbConnect? connection;
    try {
      final host = await getHost();
      final username = await getUsername();
      final password = await getPassword();
      final configPath = await getConfigFilePath();

      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: username,
        password: password,
      );

      final fileObj = await connection.file(configPath);
      final stream = await connection.openRead(fileObj);

      final List<int> excelFileBytes = [];
      await for (var chunk in stream) {
        excelFileBytes.addAll(chunk);
      }

      await connection.close();

      if (excelFileBytes.isNotEmpty) {
        await syncConfigWithServer(
          excelFileBytes,
          clearSessionOnUpdate: clearSessionOnUpdate,
        );
      }
    } catch (e) {

      debugPrint('⚠️ خطأ أثناء مزامنة الإعدادات من السيرفر: $e');
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  // ==========================================
  // 3. دوال الجلب (Getters) لاستخدامها في باقي التطبيق
  // ==========================================

  static Future<String> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('host') ?? AppConfig.defaultHost;
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? AppConfig.defaultUsername;
  }

  static Future<String> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password') ?? AppConfig.defaultPassword;
  }

  static Future<String> getAdminPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_password') ?? AppConfig.defaultAdminPassword;
  }

  static Future<String> getArticleRemotePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('article_remote_path') ?? AppConfig.defaultArticleRemotePath;
  }

  static Future<List<String>> getArticleSubfolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('article_subfolders') ?? AppConfig.defaultArticleSubfolders;
  }

  static Future<String> getExcelRemotePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('excel_remote_path') ?? AppConfig.defaultExcelRemotePath;
  }

  static Future<List<String>> getExcelSubfolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('excel_subfolders') ?? AppConfig.defaultExcelSubfolders;
  }

  static Future<String> getConfigFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('config_file_path') ?? AppConfig.defaultConfigFilePath;
  }

  static Future<String> getAdvancesFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('advances_file_path') ?? AppConfig.defaultAdvancesFilePath;
  }
}