import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:excel/excel.dart';

// 🚀 استدعاء ملف الإعدادات الديناميكي الجديد
import '../../core/config_sync_manager/config_sync_manager.dart'; // تأكد من صحة مسار الاستدعاء لديك

class AppUser {
  final String username;
  final String password;

  AppUser({required this.username, required this.password});
}

// --- States ---
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoadingUsers extends AuthState {}
class AuthUsersLoaded extends AuthState {
  final List<AppUser> users;
  AuthUsersLoaded(this.users);
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
class AuthLoggingIn extends AuthState {
  final List<AppUser> users; // Keep users to render the dropdown
  AuthLoggingIn(this.users);
}
class AuthSuccess extends AuthState {
  final String loggedInUser;
  AuthSuccess(this.loggedInUser);
}

// --- Cubit ---
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  List<AppUser> _cachedUsers = [];

  // 1. Fetch Users from Excel on the Server
  Future<void> fetchUsersFromServer() async {
    emit(AuthLoadingUsers());

    try {
      // 🚀 قراءة بيانات الاتصال ومسار الملف من مدير الإعدادات الديناميكي
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();
      final configPath = await ConfigSyncManager.getConfigFilePath();

      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      // 🚀 استخدام المسار الديناميكي بدلاً من المسار الثابت
      final fileObj = await connection.file(configPath);
      final stream = await connection.openRead(fileObj);

      final List<int> bytesList = [];
      await for (var chunk in stream) {
        bytesList.addAll(chunk);
      }
      await connection.close();

      final bytes = Uint8List.fromList(bytesList);
      final excel = Excel.decodeBytes(bytes);

      // Look specifically for the 'users' sheet
      if (!excel.tables.containsKey('users')) {
        emit(AuthError('لم يتم العثور على ورقة "users" داخل ملف الإعدادات.'));
        return;
      }

      final sheet = excel.tables['users']!;
      List<AppUser> loadedUsers = [];

      // 🚀 أداة تتبع الأسماء المكررة لمنع خطأ الـ Dropdown
      Set<String> seenUsernames = {};

      // Loop through rows (assuming row 0 might be headers like Username | Password)
      for (int i = 1; i < sheet.maxRows; i++) {
        final userCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString().trim();
        final passCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString().trim();

        if (userCell != null && userCell.isNotEmpty) {
          // 🚀 التحقق: هل أضفنا هذا الاسم سابقاً؟ إذا لا، أضفه للقائمة
          if (!seenUsernames.contains(userCell)) {
            loadedUsers.add(AppUser(username: userCell, password: passCell ?? ""));
            seenUsernames.add(userCell); // تسجيل الاسم كـ "مقروء"
          }
        }
      }

      if (loadedUsers.isEmpty) {
        emit(AuthError('قائمة المستخدمين فارغة في ملف الإكسل.'));
      } else {
        _cachedUsers = loadedUsers;
        emit(AuthUsersLoaded(_cachedUsers));
      }

    } catch (e) {
      emit(AuthError('فشل الاتصال بالخادم لجلب المستخدمين. تأكد من الشبكة.\n$e'));
    }
  }

  // 2. Validate Login locally against the fetched list
  Future<void> login(String selectedUsername, String enteredPassword) async {
    emit(AuthLoggingIn(_cachedUsers));

    // Simulate a tiny delay for UX
    await Future.delayed(const Duration(milliseconds: 600));

    final user = _cachedUsers.firstWhere(
          (u) => u.username == selectedUsername,
      orElse: () => AppUser(username: '', password: ''),
    );

    if (user.username.isNotEmpty && user.password == enteredPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedInUser', selectedUsername);
      emit(AuthSuccess(selectedUsername));
    } else {
      emit(AuthError('كلمة المرور غير صحيحة.'));
      // Re-emit loaded state so they can try again
      emit(AuthUsersLoaded(_cachedUsers));
    }
  }

  // 3. Handle Logout & Reset State
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUser'); // Clear the session

    // Reset the state back to the user list without fetching from the server again
    if (_cachedUsers.isNotEmpty) {
      emit(AuthUsersLoaded(_cachedUsers));
    } else {
      emit(AuthInitial());
      fetchUsersFromServer(); // Fallback just in case cache is empty
    }
  }

  // 4. Check Session
  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInUser = prefs.getString('loggedInUser');

    if (loggedInUser != null && loggedInUser.isNotEmpty) {
      // Session exists, instantly log them in
      emit(AuthSuccess(loggedInUser));
    } else {
      // No session, fetch users to populate the login screen
      fetchUsersFromServer();
    }
  }
}