import "package:flutter/foundation.dart"
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import "dart:convert";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

import "../models/recipe.dart";

class RecipeApi {
  static String get _endpoint => "${_baseUrl()}/api/recipes";
  static String get _categoriesEndpoint => "${_baseUrl()}/api/categories";
  static String get _searchEndpoint =>
      "${_baseUrl()}/api/recipes/searchByIngredients";

  static String _baseUrl() {
    if (kIsWeb) {
      return "http://localhost:8080";
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator uses 10.0.2.2 to reach the host machine's localhost
      return "http://10.0.2.2:8080";
    }

    return "http://localhost:8080";
  }

  static Future<List<Recipe>> fetchRecipes() async {
    final response = await http.get(Uri.parse(_endpoint));
    if (response.statusCode != 200) {
      throw Exception("Failed to load recipes (${response.statusCode}).");
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception("Unexpected recipes response.");
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList();
  }

  static Future<List<Category>> fetchCategories() async {
    final response = await http.get(Uri.parse(_categoriesEndpoint));
    if (response.statusCode != 200) {
      throw Exception("Failed to load categories (${response.statusCode}).");
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception("Unexpected categories response.");
    }

    return decoded
        .map(Category.fromDynamic)
        .where((category) => category.name.trim().isNotEmpty)
        .toList();
  }

  static Future<List<Recipe>> searchByIngredients(
    List<String> names,
  ) async {
    final cleaned = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return fetchRecipes();
    }

    final uri = Uri.parse(_searchEndpoint).replace(
      queryParameters: {
        "names": cleaned.join(","),
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        "Failed to search recipes (${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception("Unexpected search response.");
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList();
  }

  /// Rate a recipe (create or update the current user's rating).
  /// PUT {{base_url}}/api/recipes/{{recipe_id}}/rating
  /// Body: { "stars": 1–5 }
  static Future<Map<String, dynamic>> rateRecipe({
    required int recipeId,
    required int stars,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('No authentication token found. Please log in first.');
    }

    final url = Uri.parse("$_endpoint/$recipeId/rating");
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'stars': stars}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to rate recipe (${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'stars': stars};
  }
}
