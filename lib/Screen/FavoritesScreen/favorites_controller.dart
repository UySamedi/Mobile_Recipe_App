import 'package:get/get.dart';

import '../../models/recipe.dart';

class FavoritesController extends GetxController {
  final RxList<Recipe> favorites = <Recipe>[].obs;

  bool isFavorite(Recipe recipe) {
    return favorites.any((item) => _sameRecipe(item, recipe));
  }

  void toggleFavorite(Recipe recipe) {
    if (isFavorite(recipe)) {
      favorites.removeWhere((item) => _sameRecipe(item, recipe));
    } else {
      favorites.add(recipe);
    }
  }

  static bool _sameRecipe(Recipe a, Recipe b) {
    if (a.id != 0 && b.id != 0) {
      return a.id == b.id;
    }
    return a.name == b.name && a.imageUrl == b.imageUrl;
  }
}
