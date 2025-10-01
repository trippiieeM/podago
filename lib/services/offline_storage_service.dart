// services/offline_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineStorageService {
  static const String _pendingLogsKey = 'pending_milk_logs';

  // Save milk log offline
  static Future<void> saveMilkLogOffline(Map<String, dynamic> milkLog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingLogs = prefs.getStringList(_pendingLogsKey) ?? [];
      
      // Add timestamp for offline storage and ensure all fields are present
      milkLog['offlineTimestamp'] = DateTime.now().millisecondsSinceEpoch;
      milkLog['isOffline'] = true;
      
      // Make sure farmerName is included
      if (!milkLog.containsKey('farmerName') || milkLog['farmerName'] == null) {
        milkLog['farmerName'] = 'Unknown Farmer'; // Fallback
      }
      
      pendingLogs.add(json.encode(milkLog));
      await prefs.setStringList(_pendingLogsKey, pendingLogs);
    } catch (e) {
      throw Exception('Failed to save offline: $e');
    }
  }

  // Get all pending milk logs
  static Future<List<Map<String, dynamic>>> getPendingMilkLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingLogs = prefs.getStringList(_pendingLogsKey) ?? [];
      
      return pendingLogs.map((log) {
        final decodedLog = Map<String, dynamic>.from(json.decode(log));
        
        // Ensure farmerName exists with fallback
        if (!decodedLog.containsKey('farmerName') || decodedLog['farmerName'] == null) {
          decodedLog['farmerName'] = 'Unknown Farmer';
        }
        
        return decodedLog;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Remove specific milk log after successful sync
  static Future<void> removePendingMilkLog(Map<String, dynamic> milkLog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingLogs = prefs.getStringList(_pendingLogsKey) ?? [];
      
      // Find and remove the specific log
      pendingLogs.removeWhere((log) {
        final decodedLog = Map<String, dynamic>.from(json.decode(log));
        return decodedLog['offlineTimestamp'] == milkLog['offlineTimestamp'];
      });
      
      await prefs.setStringList(_pendingLogsKey, pendingLogs);
    } catch (e) {
      throw Exception('Failed to remove pending log: $e');
    }
  }

  // Clear all pending logs
  static Future<void> clearAllPendingLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingLogsKey);
    } catch (e) {
      throw Exception('Failed to clear pending logs: $e');
    }
  }

  // Get count of pending logs
  static Future<int> getPendingLogsCount() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingLogs = prefs.getStringList(_pendingLogsKey) ?? [];
    return pendingLogs.length;
  }
}