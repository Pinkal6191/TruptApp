import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RouteTracker {
  static const String _keyRouteName = 'saved_route_name';
  static const String _keyRouteData = 'saved_route_data';

  static Future<void> saveRoute(String name, {Map<String, dynamic>? data}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRouteName, name);
      if (data != null) {
        await prefs.setString(_keyRouteData, json.encode(data));
      } else {
        await prefs.remove(_keyRouteData);
      }
    } catch (_) {}
  }

  static Future<void> clearRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRouteName);
      await prefs.remove(_keyRouteData);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getSavedRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_keyRouteName);
      if (name == null) return null;
      final dataStr = prefs.getString(_keyRouteData);
      Map<String, dynamic>? data;
      if (dataStr != null) {
        try {
          data = json.decode(dataStr) as Map<String, dynamic>;
        } catch (_) {}
      }
      return {
        'name': name,
        'data': data,
      };
    } catch (_) {
      return null;
    }
  }
}
