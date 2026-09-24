import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodLog {
  final String id;
  final String foodName;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final DateTime createdAt;

  FoodLog({
    required this.id,
    required this.foodName,
    required this.calories,
    this.protein = 0.0,
    this.carbs = 0.0,
    this.fats = 0.0,
    required this.createdAt,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'],
      foodName: json['food_name'],
      calories: json['calories'],
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fats: (json['fats'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class DietService {
  // Singleton
  static final DietService _instance = DietService._internal();
  factory DietService() => _instance;
  DietService._internal();

  final _client = Supabase.instance.client;

  /// Fetch food logs for the current user for TODAY
  Future<List<FoodLog>> getTodayLogs() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    // Start of day (00:00:00) — use UTC for Supabase timestamp comparison
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    // End of day (23:59:59)
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toUtc().toIso8601String();

    try {
      final response = await _client
          .from('food_logs')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .order('created_at', ascending: true);

      final List<dynamic> data = response;
      return data.map((json) => FoodLog.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching food logs: $e');
      return [];
    }
  }

  /// Add a new food log
  Future<void> addFoodLog({
    required String foodName,
    required int calories,
    double protein = 0.0,
    double carbs = 0.0,
    double fats = 0.0,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    debugPrint(
      "DietService: Adding $foodName (C:$calories P:$protein C:$carbs F:$fats)",
    );

    await _client.from('food_logs').insert({
      'user_id': user.id,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      // created_at defaults to now() in SQL
    });
  }

  /// Delete a log
  Future<void> deleteFoodLog(String id) async {
    await _client.from('food_logs').delete().eq('id', id);
  }

  /// Update a food log
  Future<void> updateFoodLog({
    required String id,
    required String foodName,
    required int calories,
    double protein = 0.0,
    double carbs = 0.0,
    double fats = 0.0,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await _client
        .from('food_logs')
        .update({
          'food_name': foodName,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fats': fats,
        })
        .eq('id', id);
  }

  /// Get distinct past meals for quick selection
  /// Note: Supabase doesn't support direct DISTINCT ON via SDK easily in one go for all fields
  /// We will fetch recent 50 logs and dedup client side for simplicity
  Future<List<FoodLog>> getRecentMeals() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('food_logs')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> data = response;
      final List<FoodLog> allLogs = data
          .map((json) => FoodLog.fromJson(json))
          .toList();

      // Deduplicate by food name (case insensitive)
      final Map<String, FoodLog> uniqueMeals = {};
      for (var log in allLogs) {
        final key = log.foodName.trim().toLowerCase();
        if (!uniqueMeals.containsKey(key)) {
          uniqueMeals[key] = log;
        }
      }

      return uniqueMeals.values.toList();
    } catch (e) {
      debugPrint("Error fetching recent meals: $e");
      return [];
    }
  }
}
