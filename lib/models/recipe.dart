class Recipe {
  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.calory,
    required this.instructions,
    required this.youtubeLink,
    required this.category,
    required this.ingredients,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int? calory;
  final String instructions;
  final String? youtubeLink;
  final Category category;
  final List<RecipeIngredient> ingredients;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: ((json["id"] ?? 0) as num).toInt(),
      name: (json["name"] ?? "") as String,
      description: (json["description"] ?? "") as String,
      imageUrl: (json["imageUrl"] ?? "") as String,
      rating: ((json["rating"] ?? 0) as num).toDouble(),
      calory: json["calory"] == null ? null : (json["calory"] as num).toInt(),
      instructions: (json["instructions"] ?? "") as String,
      youtubeLink: json["youtubeLink"] as String?,
      category: Category.fromJson(
        (json["category"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ),
      ingredients: _parseIngredients(json["ingredients"]),
    );
  }

  static List<RecipeIngredient> _parseIngredients(dynamic value) {
    if (value is! List) {
      return const <RecipeIngredient>[];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(RecipeIngredient.fromJson)
        .toList();
  }
}

class Category {
  Category({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: ((json["id"] ?? 0) as num).toInt(),
      name: (json["name"] ?? "") as String,
    );
  }
}

class Ingredient {
  Ingredient({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: ((json["id"] ?? 0) as num).toInt(),
      name: (json["name"] ?? "") as String,
    );
  }
}

class RecipeIngredient {
  RecipeIngredient({
    required this.id,
    required this.ingredient,
    required this.quantity,
  });

  final int id;
  final Ingredient ingredient;
  final String quantity;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: ((json["id"] ?? 0) as num).toInt(),
      ingredient: Ingredient.fromJson(
        (json["ingredient"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ),
      quantity: (json["quantity"] ?? "") as String,
    );
  }
}
