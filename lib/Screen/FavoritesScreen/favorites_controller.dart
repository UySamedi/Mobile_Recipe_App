import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../models/recipe.dart';
import '../../services/recipe_api.dart';

class FavoritesController extends GetxController {
  final RxList<Recipe> favorites = <Recipe>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  String _activeUserScope = '';

  String _normalizeScopePart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');
  }

  String? _extractUserIdentityFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return null;
      }
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final userId = decoded['userId'] ?? decoded['id'] ?? decoded['sub'];
      if (userId != null && userId.toString().trim().isNotEmpty) {
        return 'id_${_normalizeScopePart(userId.toString())}';
      }

      final email = decoded['email'];
      if (email is String && email.trim().isNotEmpty) {
        return 'email_${_normalizeScopePart(email)}';
      }
    } catch (_) {
      // Ignore malformed token payload.
    }
    return null;
  }

  Future<String> _resolveUserScope() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('access_token') ?? prefs.getString('token'))
        ?.trim();

    if (token == null || token.isEmpty) {
      return '';
    }

    final fromToken = _extractUserIdentityFromToken(token);
    if (fromToken != null && fromToken.isNotEmpty) {
      return fromToken;
    }

    final email = (prefs.getString('email') ?? '').trim();
    if (email.isNotEmpty) {
      return 'email_${_normalizeScopePart(email)}';
    }

    return 'authenticated';
  }

  bool isFavorite(Recipe recipe) {
    return favorites.any((item) => _sameRecipe(item, recipe));
  }

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
  }

  /// Load all favorite recipes from the API
  Future<void> loadFavorites() async {
    final userScope = await _resolveUserScope();

    // No logged-in user: clear stale favorites from previous session.
    if (userScope.isEmpty) {
      _activeUserScope = '';
      favorites.clear();
      errorMessage.value = '';
      return;
    }

    // User switched: clear old account data before loading new account favorites.
    if (_activeUserScope != userScope) {
      _activeUserScope = userScope;
      favorites.clear();
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final favs = await RecipeApi.getMyFavorites();
      favorites.assignAll(favs);
    } catch (e) {
      final text = e.toString();
      if (text.contains('No authentication token found')) {
        favorites.clear();
        errorMessage.value = '';
        return;
      }
      errorMessage.value = text;
      print('Error loading favorites: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Toggle favorite status for a recipe (add or remove)
  Future<void> toggleFavorite(Recipe recipe) async {
    final wasAdded = isFavorite(recipe);
    try {
      if (wasAdded) {
        // Remove from favorites
        await RecipeApi.removeFavorite(recipe.id);
        favorites.removeWhere((item) => _sameRecipe(item, recipe));
      } else {
        // Add to favorites
        await RecipeApi.addFavorite(recipe.id);
        favorites.add(recipe);
      }
      errorMessage.value = '';
    } catch (e) {
      errorMessage.value = e.toString();
      print('Error toggling favorite: $e');
      // Revert the change if API call failed
      if (wasAdded) {
        favorites.add(recipe);
      } else {
        favorites.removeWhere((item) => _sameRecipe(item, recipe));
      }
    }
  }

  static bool _sameRecipe(Recipe a, Recipe b) {
    if (a.id != 0 && b.id != 0) {
      return a.id == b.id;
    }
    return a.name == b.name && a.imageUrl == b.imageUrl;
  }
}
