import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalLibrary {
  static const _projects = 'otakudub_local_projects_v1';
  static const _theme = 'otakudub_theme_v1';
  static const _motion = 'otakudub_motion_v1';

  static Future<List<Map<String, dynamic>>> projects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_projects);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveProject(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await projects();
    items.removeWhere((e) => e['id'] == item['id']);
    items.insert(0, item);
    await prefs.setString(_projects, jsonEncode(items.take(40).toList()));
  }

  static Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await projects();
    items.removeWhere((e) => e['id'] == id);
    await prefs.setString(_projects, jsonEncode(items));
  }

  static Future<String> theme() async =>
      (await SharedPreferences.getInstance()).getString(_theme) ?? 'dark';
  static Future<void> setTheme(String value) async =>
      (await SharedPreferences.getInstance()).setString(_theme, value);
  static Future<bool> reduceMotion() async =>
      (await SharedPreferences.getInstance()).getBool(_motion) ?? false;
  static Future<void> setReduceMotion(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_motion, value);
}
