
import 'package:shared_preferences/shared_preferences.dart';

class RoleManager {
  static const String _permissionsKey = 'allowedScreens';

  // Screen IDs
  static const int images = 1;
  static const int excel = 2;
  static const int employees = 3;
  static const int calculator = 4;

  // Check permission using the current AuthSuccess state.
  static bool canAccessScreen(int screenId, Set<int> permissions) {
    return permissions.contains(screenId);
  }

  // Check if a screen's data should be loaded.
  static bool shouldLoadData(int screenId, Set<int> permissions) {
    return canAccessScreen(screenId, permissions);
  }

  // Save permissions.
  static Future<void> savePermissions(Set<int> permissions) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _permissionsKey,
      permissions.map((id) => id.toString()).toList(),
    );
  }

  // Get saved permissions.
  static Future<Set<int>> getPermissions() async {
    final prefs = await SharedPreferences.getInstance();

    final screens = prefs.getStringList(_permissionsKey) ?? [];

    return screens
        .map((id) => int.tryParse(id))
        .whereType<int>()
        .toSet();
  }

  // Check saved permission.
  static Future<bool> hasAccess(int screenId) async {
    final permissions = await getPermissions();
    return permissions.contains(screenId);
  }

  // Clear permissions.
  static Future<void> clearPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionsKey);
  }
}
