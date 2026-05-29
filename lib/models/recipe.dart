class Recipe {
  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.difficulty,
    required this.preparationTimeMinutes,
    required this.cookTimeMinutes,
    required this.totalTimeMinutes,
    required this.rating,
    required this.calory,
    required this.nutrition,
    required this.instructions,
    required this.youtubeLink,
    required this.category,
    required this.ingredients,
  });

  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final String difficulty;
  final int? preparationTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  final double rating;
  final int? calory;
  final Nutrition? nutrition;
  final String instructions;
  final String? youtubeLink;
  final Category category;
  final List<RecipeIngredient> ingredients;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: _toInt(json["id"]),
      name: _toStringValue(json["name"]),
      description: _toStringValue(json["description"]),
      imageUrl: _toStringValue(json["imageUrl"]),
      difficulty: _toStringValue(json["difficulty"]),
      preparationTimeMinutes: _toIntNullable(json["preparationTimeMinutes"]),
      cookTimeMinutes: _toIntNullable(json["cookTimeMinutes"]),
      totalTimeMinutes: _toIntNullable(json["totalTimeMinutes"]),
      rating: _toDouble(json["rating"]),
      calory: _parseCalories(json),
      nutrition: Nutrition.fromDynamic(json["nutrition"]),
      instructions: _toStringValue(json["instructions"]),
      youtubeLink: json["youtubeLink"] as String?,
      category: Category.fromDynamic(json["category"]),
      ingredients: _parseIngredients(json["ingredients"]),
    );
  }

  static int? _parseCalories(Map<String, dynamic> json) {
    final calory = _toIntNullable(json["calory"]);
    if (calory != null) {
      return calory;
    }
    final nutrition = json["nutrition"];
    if (nutrition is Map<String, dynamic>) {
      return _toIntNullable(nutrition["calories"]);
    }
    return null;
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

  factory Category.fromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Category.fromJson(value);
    }
    if (value is String) {
      return Category(id: 0, name: value);
    }
    return Category(id: 0, name: "");
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _toInt(json["id"]),
      name: _toStringValue(json["name"]),
    );
  }
}

class Nutrition {
  Nutrition({
    required this.calories,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.proteinGrams,
    required this.sodiumMg,
    required this.sugarGrams,
  });

  final int? calories;
  final int? carbsGrams;
  final int? fatGrams;
  final int? fiberGrams;
  final int? proteinGrams;
  final int? sodiumMg;
  final int? sugarGrams;

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: _toIntNullable(json["កាឡូរី"] ?? json["calories"]),
      carbsGrams: _toIntNullable(json["កាបូអ៊ីដ្រាត_ក្រាម"] ?? json["carbsGrams"]),
      fatGrams: _toIntNullable(json["ជាតិខ្លាញ់_ក្រាម"] ?? json["fatGrams"]),
      fiberGrams: _toIntNullable(json["ជាតិសរសៃ_ក្រាម"] ?? json["fiberGrams"]),
      proteinGrams: _toIntNullable(json["ប្រូតេអ៊ីន_ក្រាម"] ?? json["proteinGrams"]),
      sodiumMg: _toIntNullable(json["សូដ្យូម_មីលីក្រាម"] ?? json["sodiumMg"]),
      sugarGrams: _toIntNullable(json["ជាតិស្ករ_ក្រាម"] ?? json["sugarGrams"]),
    );
  }

  static Nutrition? fromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Nutrition.fromJson(value);
    }
    return null;
  }
}

class Ingredient {
  Ingredient({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? imageUrl;

  factory Ingredient.fromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Ingredient.fromJson(value);
    }
    if (value is String) {
      return Ingredient(id: 0, name: value);
    }
    return Ingredient(id: 0, name: "");
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: _toInt(json["id"]),
      name: _toStringValue(json["name"]),
      imageUrl: json["imageUrl"] as String?,
    );
  }
}

class RecipeIngredient {
  RecipeIngredient({
    required this.id,
    required this.ingredient,
    required this.quantity,
    this.imageUrl,
  });

  final int id;
  final Ingredient ingredient;
  final String quantity;
  final String? imageUrl;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: _parseRecipeIngredientId(json["id"]),
      ingredient: Ingredient.fromDynamic(json["ingredient"]),
      quantity: _toStringValue(json["quantity"]),
      imageUrl: json["imageUrl"] as String?,
    );
  }

  static int _parseRecipeIngredientId(dynamic value) {
    if (value is num || value is String) {
      return _toInt(value);
    }
    if (value is Map<String, dynamic>) {
      final ingredientId = _toIntNullable(value["ingredientId"]);
      if (ingredientId != null) {
        return ingredientId;
      }
      return _toInt(value["recipeId"]);
    }
    return 0;
  }
}

int _toInt(dynamic value) {
  return _toIntNullable(value) ?? 0;
}

int? _toIntNullable(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

String _toStringValue(dynamic value) {
  if (value == null) {
    return "";
  }
  return value.toString();
}
