
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:excel/excel.dart';

import '../../core/config_sync_manager/config_sync_manager.dart';
import '../../core/config_sync_manager/role_manager/role_manager.dart';

// ==========================================
// 1. APP USER MODEL
// ==========================================

class AppUser {
  final String username;
  final String password;
  final Set<int> allowedScreens;

  AppUser({
    required this.username,
    required this.password,
    required this.allowedScreens,
  });
}

// ==========================================
// 2. AUTH STATES
// ==========================================

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
  final List<AppUser> users;

  AuthLoggingIn(this.users);
}

class AuthSuccess extends AuthState {
  final String loggedInUser;
  final Set<int> allowedScreens;

  AuthSuccess(this.loggedInUser, this.allowedScreens);
}

// ==========================================
// 3. AUTH CUBIT
// ==========================================

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  List<AppUser> _cachedUsers = [];

  // ==========================================
  // 4. FETCH USERS AND ROLES FROM EXCEL
  // ==========================================

  Future<void> fetchUsersFromServer() async {
    emit(AuthLoadingUsers());

    SmbConnect? connection;

    try {
      // Get dynamic SMB configuration.
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();
      final configPath = await ConfigSyncManager.getConfigFilePath();

      // Connect to SMB server.
      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      // Download Excel file.
      final fileObj = await connection.file(configPath);
      final stream = await connection.openRead(fileObj);

      final List<int> bytesList = [];

      await for (final chunk in stream) {
        bytesList.addAll(chunk);
      }

      await connection.close();
      connection = null;

      if (bytesList.isEmpty) {
        emit(AuthError('ملف الإعدادات فارغ.'));
        return;
      }

      // Decode Excel.
      final excel = Excel.decodeBytes(
        Uint8List.fromList(bytesList),
      );

      // Find users sheet.
      final sheet = excel.tables['users'];

      if (sheet == null) {
        emit(AuthError(
          'لم يتم العثور على ورقة "users" داخل ملف الإعدادات.',
        ));
        return;
      }

      // ==========================================
      // READ SCREEN IDS FROM HEADER ROW
      // ==========================================

      final Map<int, int> screenColumns = {};

      for (int col = 2; col < sheet.maxColumns; col++) {
        final header = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: 0,
          ),
        ).value;

        if (header == null) continue;

        final screenId = double.tryParse(
          header.toString().trim(),
        )?.toInt();

        if (screenId != null) {
          screenColumns[screenId] = col;
        }
      }

      if (screenColumns.isEmpty) {
        emit(AuthError(
          'لم يتم العثور على أرقام الشاشات في الصف الأول.',
        ));
        return;
      }

      // ==========================================
      // READ USERS
      // ==========================================

      final List<AppUser> loadedUsers = [];

      final Set<String> seenUsernames = {};

      for (int row = 1; row < sheet.maxRows; row++) {
        final username = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: row,
          ),
        ).value?.toString().trim() ?? '';

        final password = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: row,
          ),
        ).value?.toString().trim() ?? '';

        if (username.isEmpty) continue;

        // Avoid duplicate usernames.
        if (seenUsernames.contains(username)) continue;

        // ==========================================
        // READ USER PERMISSIONS
        // ==========================================

        final Set<int> allowedScreens = {};

        for (final entry in screenColumns.entries) {
          final int screenId = entry.key;
          final int column = entry.value;

          final permission = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: row,
            ),
          ).value?.toString().trim().toUpperCase() ?? '';

          if (permission == 'YES') {
            allowedScreens.add(screenId);
          }
        }

        loadedUsers.add(
          AppUser(
            username: username,
            password: password,
            allowedScreens: allowedScreens,
          ),
        );

        seenUsernames.add(username);
      }

      // ==========================================
      // UPDATE CACHED USERS
      // ==========================================
      if (loadedUsers.isEmpty) {
        emit(AuthError('قائمة المستخدمين فارغة في ملف الإكسل.'));
        return;
      }

      _cachedUsers = loadedUsers;

// Check if there is an existing session.
      final prefs = await SharedPreferences.getInstance();

      final loggedInUser = prefs.getString('loggedInUser');

      if (loggedInUser != null && loggedInUser.isNotEmpty) {

        // Find the logged-in user in the latest Excel data.
        AppUser? currentUser;

        for (final user in _cachedUsers) {
          if (user.username == loggedInUser) {
            currentUser = user;
            break;
          }
        }

        if (currentUser != null) {

          // Update permissions using the latest Excel values.
          await RoleManager.savePermissions(
            currentUser.allowedScreens,
          );

          debugPrint('Permissions updated from server:');
          debugPrint('${currentUser.allowedScreens}');

          emit(
            AuthSuccess(
              currentUser.username,
              currentUser.allowedScreens,
            ),
          );

        } else {

          // User was removed from Excel.
          await prefs.remove('loggedInUser');
          await RoleManager.clearPermissions();

          emit(AuthUsersLoaded(_cachedUsers));
        }

      } else {

        // No active session. Show login screen.
        emit(AuthUsersLoaded(_cachedUsers));
      }
    } catch (e) {
      emit(AuthError(
        'فشل الاتصال بالخادم لجلب المستخدمين. تأكد من الشبكة.\n$e',
      ));
    } finally {
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  // ==========================================
  // 5. LOGIN
  // ==========================================


  Future<void> login(
      String selectedUsername,
      String enteredPassword,
      ) async {
    // Always fetch the latest Excel data before login.
    await fetchUsersFromServer();

    // If fetching failed, don't continue with old cached data.
    if (state is! AuthUsersLoaded) {
      return;
    }

    emit(AuthLoggingIn(_cachedUsers));

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    AppUser? user;

    for (final currentUser in _cachedUsers) {
      if (currentUser.username == selectedUsername) {
        user = currentUser;
        break;
      }
    }

    if (user != null && user.password == enteredPassword) {
      try {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          'loggedInUser',
          user.username,
        );

        // Save the latest Excel permissions.
        await RoleManager.savePermissions(
          user.allowedScreens,
        );

        debugPrint('Login successful: ${user.username}');
        debugPrint('Latest permissions: ${user.allowedScreens}');

        emit(
          AuthSuccess(
            user.username,
            user.allowedScreens,
          ),
        );
      } catch (e) {
        emit(AuthError('فشل حفظ بيانات تسجيل الدخول: $e'));
        emit(AuthUsersLoaded(_cachedUsers));
      }
    } else {
      emit(AuthError('كلمة المرور غير صحيحة.'));
      emit(AuthUsersLoaded(_cachedUsers));
    }
  }


  // ==========================================
  // 6. LOGOUT
  // ==========================================


  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('loggedInUser');

    await RoleManager.clearPermissions();

    // Clear old Excel data from memory.
    _cachedUsers.clear();

    // Fetch fresh users for the login screen.
    await fetchUsersFromServer();
  }


  // ==========================================
  // 7. CHECK SESSION
  // ==========================================

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();

    final loggedInUser = prefs.getString('loggedInUser');

    if (loggedInUser != null && loggedInUser.isNotEmpty) {
      debugPrint('Checking latest permissions for: $loggedInUser');
    } else {
      debugPrint('No saved session. Loading users for login.');
    }

    // Always download the latest users and permissions from SMB.
    await fetchUsersFromServer();
  }

  // ==========================================
  // 8. GET CURRENT USER
  // ==========================================

  Future<String?> getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('loggedInUser');
  }

  // ==========================================
  // 9. GET CURRENT USER PERMISSIONS
  // ==========================================

  Future<Set<int>> getCurrentPermissions() async {
    return await RoleManager.getPermissions();
  }

  // ==========================================
  // 10. CHECK SCREEN ACCESS
  // ==========================================

  Future<bool> hasScreenAccess(int screenId) async {
    return await RoleManager.hasAccess(screenId);
  }
}
