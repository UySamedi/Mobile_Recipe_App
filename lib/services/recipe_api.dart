import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

import "../models/recipe.dart";

class RecipeApi {
  static String get _endpoint => "${_baseUrl()}/api/recipes";

  static String _baseUrl() {
    if (kIsWeb) {
      return "http://localhost:8080";
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8080";

      //  real device
            // http://172.31.98.145:8080

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
}
