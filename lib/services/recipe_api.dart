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

  static String _authHeaderValue(String token) {
    final normalized = token.trim();
    if (normalized.toLowerCase().startsWith('bearer ')) {
      return normalized;
    }
    return 'Bearer $normalized';
  }

  static String? _readAccessToken(SharedPreferences prefs) {
    return (prefs.getString('access_token') ?? prefs.getString('token'))
        ?.trim();
  }

  static String _extractErrorMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'No error details provided by server.';
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['error'] ?? decoded['detail'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } catch (_) {
      // Response is not JSON, return raw text.
    }
    return trimmed;
  }

  static int? _extractFavoriteRecipeId(Map<String, dynamic> item) {
    final idValue = item['id'];
    if (idValue is Map<String, dynamic>) {
      final fromComposite = idValue['recipeId'];
      if (fromComposite is num) {
        return fromComposite.toInt();
      }
      if (fromComposite is String) {
        return int.tryParse(fromComposite);
      }

      final fromCompositeSnake = idValue['recipe_id'];
      if (fromCompositeSnake is num) {
        return fromCompositeSnake.toInt();
      }
      if (fromCompositeSnake is String) {
        return int.tryParse(fromCompositeSnake);
      }
    }

    final direct = item['recipeId'];
    if (direct is num) {
      return direct.toInt();
    }
    if (direct is String) {
      return int.tryParse(direct);
    }

    final directSnake = item['recipe_id'];
    if (directSnake is num) {
      return directSnake.toInt();
    }
    if (directSnake is String) {
      return int.tryParse(directSnake);
    }

    final nestedRecipe = item['recipe'];
    if (nestedRecipe is Map<String, dynamic>) {
      return _extractFavoriteRecipeId(nestedRecipe);
    }

    return null;
  }

  static bool _looksLikeRecipePayload(Map<String, dynamic> map) {
    return map['name'] != null ||
        map['imageUrl'] != null ||
        map['description'] != null ||
        map['instructions'] != null;
  }

  static Future<Recipe?> _fetchRecipeById({
    required int recipeId,
    required String authHeader,
  }) async {
    final url = Uri.parse("$_endpoint/$recipeId");
    final response = await http.get(
      url,
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Recipe.fromJson(decoded);
    }
    return null;
  }

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

  static Future<List<Recipe>> searchByIngredients(List<String> names) async {
    final cleaned = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return fetchRecipes();
    }

    final uri = Uri.parse(
      _searchEndpoint,
    ).replace(queryParameters: {"names": cleaned.join(",")});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception("Failed to search recipes (${response.statusCode}).");
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
    final token = _readAccessToken(prefs);

    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found. Please log in first.');
    }

    final url = Uri.parse("$_endpoint/$recipeId/rating");
    final response = await http.put(
      url,
      headers: {
        'Authorization': _authHeaderValue(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'stars': stars}),
    );

    // Accept all 2xx responses because backend may return 200 (update)
    // or 201 (create) for the same endpoint.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final reason = _extractErrorMessage(response.body);
      throw Exception(
        "Failed to rate recipe (${response.statusCode}): $reason",
      );
    }

    if (response.body.trim().isEmpty) {
      return {'stars': stars};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'stars': stars};
  }

  /// Add a recipe to favorites
  /// POST {{base_url}}/api/recipes/{{recipe_id}}/favorite (protected)
  static Future<Map<String, dynamic>> addFavorite(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = _readAccessToken(prefs);

    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found. Please log in first.');
    }

    final url = Uri.parse("$_endpoint/$recipeId/favorite");
    final response = await http.post(
      url,
      headers: {
        'Authorization': _authHeaderValue(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to add recipe to favorites (${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'message': 'Recipe added to favorites'};
  }

  /// Remove a recipe from favorites
  /// DELETE {{base_url}}/api/recipes/{{recipe_id}}/favorite (protected)
  static Future<Map<String, dynamic>> removeFavorite(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = _readAccessToken(prefs);

    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found. Please log in first.');
    }

    final url = Uri.parse("$_endpoint/$recipeId/favorite");
    final response = await http.delete(
      url,
      headers: {
        'Authorization': _authHeaderValue(token),
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to remove recipe from favorites (${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'message': 'Recipe removed from favorites'};
  }

  /// Check if a recipe is in favorites
  /// GET {{base_url}}/api/recipes/{{recipe_id}}/favorite/check (optional auth)
  /// Returns: { "isFavorite": true/false }
  static Future<bool> isFavorite(int recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = _readAccessToken(prefs);

    final url = Uri.parse("$_endpoint/$recipeId/favorite/check");
    final response = await http.get(
      url,
      headers: {
        if (token != null && token.isNotEmpty)
          'Authorization': _authHeaderValue(token),
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to check favorite status (${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['isFavorite'] == true;
    }
    return false;
  }

  /// Get all favorite recipes for the current user
  /// GET {{base_url}}/api/recipes/favorites/my-favorites (protected)
  static Future<List<Recipe>> getMyFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final token = _readAccessToken(prefs);

    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found. Please log in first.');
    }

    final url = Uri.parse("${_baseUrl()}/api/recipes/favorites/my-favorites");
    final authHeader = _authHeaderValue(token);
    final response = await http.get(
      url,
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to load favorite recipes (${response.statusCode}).",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception("Unexpected favorites response.");
    }

    final results = <Recipe>[];
    Map<int, Recipe>? recipeCacheById;

    Future<Recipe?> resolveRecipeById(int recipeId) async {
      final byEndpoint = await _fetchRecipeById(
        recipeId: recipeId,
        authHeader: authHeader,
      );
      if (byEndpoint != null) {
        return byEndpoint;
      }

      // Fallback when /api/recipes/{id} is unavailable in backend.
      recipeCacheById ??= {
        for (final recipe in await fetchRecipes()) recipe.id: recipe,
      };
      return recipeCacheById![recipeId];
    }

    for (final item in decoded.whereType<Map<String, dynamic>>()) {
      // Primary shape: item contains nested recipe object.
      final nestedRecipe = item['recipe'];
      if (nestedRecipe is Map<String, dynamic> &&
          _looksLikeRecipePayload(nestedRecipe)) {
        results.add(Recipe.fromJson(nestedRecipe));
        continue;
      }

      // Alternate shape: item is already a recipe object.
      if (_looksLikeRecipePayload(item)) {
        results.add(Recipe.fromJson(item));
        continue;
      }

      // Fallback: relation object contains only recipeId, fetch full recipe.
      final recipeId = _extractFavoriteRecipeId(item);
      if (recipeId != null && recipeId > 0) {
        final fullRecipe = await resolveRecipeById(recipeId);
        if (fullRecipe != null) {
          results.add(fullRecipe);
        }
      }
    }

    return results;
  }
}
