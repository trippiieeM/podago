import 'package:shared_preferences/shared_preferences.dart';

class SimpleStorageService {
  static const String _userRoleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _lastLoginKey = 'last_login';
  static const String _authTypeKey = 'auth_type';

  // Save PIN-based farmer session
  static Future<void> savePinSession({
    required String userId,
    required String userName,
    required String role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userNameKey, userName);
      await prefs.setString(_userRoleKey, role);
      await prefs.setString(_authTypeKey, 'pin');
      await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
      print('💾 PIN Session saved - User: $userId, Role: $role, Name: $userName');
    } catch (e) {
      print('❌ Error saving PIN session: $e');
      rethrow;
    }
  }

  // Save Firebase Auth session
  static Future<void> saveFirebaseSession({
    required String userId,
    required String userEmail,
    required String role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userEmailKey, userEmail);
      await prefs.setString(_userRoleKey, role);
      await prefs.setString(_authTypeKey, 'firebase');
      await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
      print('💾 Firebase Session saved - User: $userId, Role: $role, Email: $userEmail');
    } catch (e) {
      print('❌ Error saving Firebase session: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      final userEmail = prefs.getString(_userEmailKey);
      final userName = prefs.getString(_userNameKey);
      final role = prefs.getString(_userRoleKey);
      final lastLogin = prefs.getString(_lastLoginKey);
      final authType = prefs.getString(_authTypeKey);

      if (userId == null || role == null) {
        return null;
      }

      return {
        'userId': userId,
        'userEmail': userEmail ?? '',
        'userName': userName ?? '',
        'role': role,
        'lastLogin': lastLogin != null ? DateTime.parse(lastLogin) : DateTime.now(),
        'authType': authType ?? 'firebase',
      };
    } catch (e) {
      print('❌ Error reading session: $e');
      return null;
    }
  }

  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_lastLoginKey);
      await prefs.remove(_authTypeKey);
      print('🗑️ Session cleared locally');
    } catch (e) {
      print('❌ Error clearing session: $e');
    }
  }

  static Future<bool> hasValidSession() async {
    final session = await getUserSession();
    if (session == null) return false;
    
    final lastLogin = session['lastLogin'] as DateTime;
    final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
    return daysSinceLogin < 30;
  }
}