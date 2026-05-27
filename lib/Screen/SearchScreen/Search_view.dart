import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/recipe.dart';
import '../../services/recipe_api.dart';
import '../Recipe_Detail_Screen/recipe_detail_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const String _ingredientGroupAll = 'All';
  static const List<String> _ingredientGroupOrder = <String>[
    'Vegetables',
    'Meat & Seafood',
    'Dairy & Eggs',
    'Herbs & Spices',
    'Sauces & Pastes',
    'Staples',
    'Fruits',
    'Others',
  ];

  late Future<List<Recipe>> _resultsFuture;
  late Future<List<Recipe>> _allRecipesFuture;
  late Future<List<Ingredient>> _allIngredientsFuture;
  final TextEditingController _searchController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _query = '';
  String _searchQuery = '';
  String? _selectedCategoryName;
  String _selectedIngredientGroup = _ingredientGroupAll;
  final Set<String> _selectedIngredients = <String>{};
  bool _isScanningImage = false;
  List<Recipe> _allRecipesCache = const <Recipe>[];
  List<Category> _categoriesCache = const <Category>[];
  List<Ingredient> _allIngredientsCache = const <Ingredient>[];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadAllIngredients();
    _refreshAllRecipes(updateResults: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: FutureBuilder<List<Recipe>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _errorState(context, snapshot.error);
          }
          final recipes = snapshot.data ?? const <Recipe>[];
          return _buildContent(context, recipes);
        },
      ),
    );
  }

  Widget _errorState(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load recipes.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_query.trim().isEmpty) {
                  _refreshAllRecipes(updateResults: true);
                } else {
                  _runSearch();
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Recipe> recipes) {
    final categories = _buildCategories(recipes, _categoriesCache);
    if (_selectedCategoryName != null &&
        !categories.any((category) => category.id == _selectedCategoryName)) {
      _selectedCategoryName = null;
    }
    
    // Apply search filter
    List<Recipe> results;
    
    // Priority 1: If ingredients are selected by clicking, recipes are already filtered by API
    if (_selectedIngredients.isNotEmpty) {
      // recipes from FutureBuilder are already filtered by API searchByIngredients
      results = _sortByRating(recipes);
    }
    // Priority 2: If search text exists, filter locally
    else if (_searchQuery.isNotEmpty) {
      final filtered = _filterByCategory(recipes, _selectedCategoryName);
      
      // First, try to filter by ingredients in search text
      final recipesByIngredient = _filterRecipesByIngredientsSearch(filtered, _searchQuery);
      
      if (recipesByIngredient.isNotEmpty) {
        // Found recipes with matching ingredients
        results = _sortByRating(recipesByIngredient);
      } else {
        // No ingredient match - search by recipe name/description/category
        results = _sortByRating(_filterByRecipeSearch(filtered, _searchQuery));
      }
    }
    // No search - show all with category filter
    else {
      final filtered = _filterByCategory(recipes, _selectedCategoryName);
      results = _sortByRating(filtered);
    }

    final ingredientOptions = _buildIngredientOptions(
      _allRecipesCache.isEmpty ? recipes : _allRecipesCache,
    );
    final ingredientGroups = _buildIngredientGroups(ingredientOptions);
    if (!ingredientGroups.any(
      (group) => group.name == _selectedIngredientGroup,
    )) {
      _selectedIngredientGroup = _ingredientGroupAll;
    }
    final visibleIngredientOptions = _filterIngredientOptionsByGroup(
      ingredientOptions,
      _selectedIngredientGroup,
    );
    
    // Filter ingredients by search query as well
    final ingredientListToShow = _filterIngredientOptionsByText(
      visibleIngredientOptions,
      _searchQuery,
    );

    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search recipes & ingredients',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: Colors.grey.shade700,
            ),
            suffixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 96),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _query = '';
                        _searchController.clear();
                        _resultsFuture = _allRecipesFuture;
                      });
                    },
                  ),
                IconButton(
                  tooltip: 'Scan ingredients from image',
                  icon: _isScanningImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined, size: 18),
                  onPressed: _isScanningImage ? null : _scanIngredientsFromImage,
                ),
              ],
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFFE0E0E0),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF3F7A5F),
                width: 1.6,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim();
            });
          },
        ),
        const SizedBox(height: 16),
        if (ingredientOptions.isNotEmpty) ...[
          Container(
            width: double.infinity,
            height: 360,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6E6E6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ingredients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_selectedIngredients.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F7A5F),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_selectedIngredients.length} selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedIngredients.isEmpty
                      ? 'Choose ingredients to filter recipes'
                      : 'Tap again to remove selected ingredients',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedIngredients.isNotEmpty) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedIngredients.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final ingredientName = _selectedIngredients.elementAt(
                          index,
                        );
                        return _selectedIngredientChip(ingredientName);
                      },
                    ),
                  ),
                   const SizedBox(height: 10),
                 ],
                 const SizedBox(height: 10),
                 SizedBox(
                   height: 40,
                   child: ListView(
                     scrollDirection: Axis.horizontal,
                     children: ingredientGroups
                         .map(_ingredientGroupChip)
                         .toList(growable: false),
                   ),
                 ),
                const SizedBox(height: 10),
                if (_selectedIngredients.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: _clearIngredientSelection,
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear selected ingredients'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: ingredientListToShow.isEmpty
                      ? Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'No ingredients available.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      : Scrollbar(
                          child: ListView.builder(
                            itemCount: ingredientListToShow.length,
                            itemBuilder: (context, index) {
                              return _ingredientCard(
                                ingredientListToShow[index],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (categories.length > 1) ...[
          const Text(
            'Filter by category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map(_categoryChip).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          (_searchQuery.trim().isEmpty && _selectedIngredients.isEmpty)
              ? 'Popular recipes'
              : 'Results (${results.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
      ],
    );

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: topSection),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _emptyState(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: 12);
                  }
                  final recipe = results[index ~/ 2];
                  return _recipeRow(context, recipe);
                }, childCount: results.isEmpty ? 0 : results.length * 2 - 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No recipes match those ingredients.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAllRecipes({bool updateResults = false}) {
    final future = RecipeApi.fetchRecipes();
    _allRecipesFuture = future;
    if (updateResults) {
      _resultsFuture = future;
    }
    future.then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allRecipesCache = value;
      });
    });
  }

  void _loadCategories() {
    RecipeApi.fetchCategories()
        .then((value) {
          if (!mounted) {
            return;
          }
          setState(() {
            _categoriesCache = value;
          });
        })
        .catchError((_) {});
  }

  void _loadAllIngredients() {
    _allIngredientsFuture = RecipeApi.fetchAllIngredients();
    _allIngredientsFuture
        .then((value) {
          if (!mounted) {
            return;
          }
          // Force rebuild with new ingredients
          setState(() {
            _allIngredientsCache = value;
          });
        })
        .catchError((error) {
          // If API fails, silently continue with fallback (recipe-based ingredients)
        });
  }

  void _runSearch() {
    final names = _parseIngredients(_query);
    setState(() {
      _resultsFuture = names.isEmpty
          ? _allRecipesFuture
          : RecipeApi.searchByIngredients(names);
    });
  }

  Future<void> _scanIngredientsFromImage() async {
    if (_isScanningImage) {
      return;
    }

    setState(() {
      _isScanningImage = true;
    });

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedImage == null) {
        return;
      }

      final inputImage = InputImage.fromFilePath(pickedImage.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final extractedText = _normalizeRecognizedText(recognizedText.text);

        if (extractedText.isEmpty) {
          _showSearchMessage('No readable text was found in the image.');
          return;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _searchController.value = TextEditingValue(
            text: extractedText,
            selection: TextSelection.collapsed(offset: extractedText.length),
          );
          _query = extractedText;
          _searchQuery = extractedText;
        });
        _runSearch();
      } finally {
        textRecognizer.close();
      }
    } catch (_) {
      _showSearchMessage('Could not scan text from the selected image.');
    } finally {
      if (mounted) {
        setState(() {
          _isScanningImage = false;
        });
      }
    }
  }

  String _normalizeRecognizedText(String rawText) {
    return rawText
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.replaceAll(RegExp(r'^[•\-\*\u2022\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .join(', ')
        .trim();
  }

  void _showSearchMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onIngredientChipToggled(String name, bool selected) {
    setState(() {
      if (selected) {
        _selectedIngredients.add(name);
      } else {
        _selectedIngredients.remove(name);
      }
      _selectedCategoryName = null;
      _query = _selectedIngredients.join(', ');
      _resultsFuture = _selectedIngredients.isEmpty
          ? _allRecipesFuture
          : RecipeApi.searchByIngredients(_selectedIngredients.toList());
    });
  }

  List<String> _parseIngredients(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    return trimmed
        .split(RegExp(r"[,\n;]"))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  List<_CategoryFilter> _buildCategories(
    List<Recipe> recipes,
    List<Category> categoriesFromApi,
  ) {
    final Set<String> names = {};
    for (final category in categoriesFromApi) {
      final name = category.name.trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    if (names.isEmpty) {
      for (final recipe in recipes) {
        final name = recipe.category.name.trim();
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
    }
    final sortedNames = names.toList()..sort();
    return [
      const _CategoryFilter(null, 'All'),
      ...sortedNames.map((name) => _CategoryFilter(name, name)),
    ];
  }

  List<Recipe> _filterByCategory(List<Recipe> recipes, String? selectedName) {
    if (selectedName == null) {
      return recipes;
    }
    return recipes
        .where(
          (recipe) =>
              recipe.category.name.toLowerCase() == selectedName.toLowerCase(),
        )
        .toList();
  }

  List<Recipe> _filterRecipesByIngredientsSearch(List<Recipe> recipes, String query) {
    if (query.trim().isEmpty) {
      return recipes;
    }
    
    final searchQuery = query.trim();
    
    // Filter recipes that have ANY ingredient containing the search query
    return recipes.where((recipe) {
      return recipe.ingredients.any((item) {
        final ingredientName = item.ingredient.name.trim();
        return ingredientName.contains(searchQuery);
      });
    }).toList();
  }

  List<Recipe> _filterByRecipeSearch(List<Recipe> recipes, String query) {
    if (query.trim().isEmpty) {
      return recipes;
    }
    
    final searchQuery = query.trim();
    
    return recipes.where((recipe) {
      final nameMatch = recipe.name.contains(searchQuery);
      final descMatch = recipe.description.contains(searchQuery);
      final categoryMatch = recipe.category.name.contains(searchQuery);
      return nameMatch || descMatch || categoryMatch;
    }).toList();
  }

  List<Recipe> _sortByRating(List<Recipe> recipes) {
    final sorted = [...recipes]..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  List<_IngredientOption> _buildIngredientOptions(List<Recipe> recipes) {
    final Map<String, int> counts = {};
    final Map<String, String> imagesByName = {};

    // Count how many recipes contain each ingredient
    for (final recipe in recipes) {
      for (final item in recipe.ingredients) {
        final name = item.ingredient.name.trim();
        if (name.isEmpty) {
          continue;
        }
        counts.update(name, (value) => value + 1, ifAbsent: () => 1);
        final imageUrl = _resolveIngredientImageUrl(item);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          imagesByName.putIfAbsent(name, () => imageUrl);
        }
      }
    }

    final options = <_IngredientOption>[];

    // If database ingredients are loaded, use them as primary source
    if (_allIngredientsCache.isNotEmpty) {
      for (final ingredient in _allIngredientsCache) {
        final name = ingredient.name.trim();
        if (name.isEmpty) {
          continue;
        }
        final recipeCount = counts[name] ?? 0;
        final imageUrl = ingredient.imageUrl?.trim() ?? imagesByName[name];
        options.add(
          _IngredientOption(
            name,
            recipeCount,
            _classifyIngredientGroup(name),
            imageUrl,
          ),
        );
      }
    } else {
      // Fallback: build from recipes if database ingredients not yet loaded
      for (final entry in counts.entries) {
        options.add(
          _IngredientOption(
            entry.key,
            entry.value,
            _classifyIngredientGroup(entry.key),
            imagesByName[entry.key],
          ),
        );
      }
    }

    // Sort by recipe count (descending) then by name
    options.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.name.compareTo(b.name);
    });

    return options;
  }

  List<_IngredientGroup> _buildIngredientGroups(
    List<_IngredientOption> options,
  ) {
    final Map<String, int> groupCounts = {};
    for (final option in options) {
      groupCounts.update(option.group, (value) => value + 1, ifAbsent: () => 1);
    }

    final groups = <_IngredientGroup>[
      _IngredientGroup(_ingredientGroupAll, options.length),
    ];
    for (final groupName in _ingredientGroupOrder) {
      final count = groupCounts[groupName];
      if (count != null && count > 0) {
        groups.add(_IngredientGroup(groupName, count));
      }
    }
    return groups;
  }

  List<_IngredientOption> _filterIngredientOptionsByGroup(
    List<_IngredientOption> options,
    String group,
  ) {
    if (group == _ingredientGroupAll) {
      return options;
    }
    return options.where((option) => option.group == group).toList();
  }

  List<_IngredientOption> _filterIngredientOptionsByText(
    List<_IngredientOption> options,
    String query,
  ) {
    final searchQuery = query.trim();
    if (searchQuery.isEmpty) {
      return options;
    }
    
    // Direct substring matching for Khmer support
    // Check both the ingredient name and if search text is contained
    return options.where((option) {
      final name = option.name.trim();
      return name.contains(searchQuery);
    }).toList();
  }

  String _classifyIngredientGroup(String ingredientName) {
    final value = ingredientName.toLowerCase();

    if (_containsAny(value, const <String>[
      'sauce',
      'paste',
      'ketchup',
      'mayo',
    ])) {
      return 'Sauces & Pastes';
    }
    if (_containsAny(value, const <String>[
      'spinach',
      'carrot',
      'onion',
      'pepper',
      'cabbage',
      'broccoli',
      'tomato',
      'chili',
    ])) {
      return 'Vegetables';
    }
    if (_containsAny(value, const <String>[
      'fish',
      'chicken',
      'beef',
      'pork',
      'shrimp',
      'meat',
    ])) {
      return 'Meat & Seafood';
    }
    if (_containsAny(value, const <String>[
      'egg',
      'milk',
      'cheese',
      'butter',
      'yogurt',
    ])) {
      return 'Dairy & Eggs';
    }
    if (_containsAny(value, const <String>[
      'garlic',
      'ginger',
      'mint',
      'basil',
      'coriander',
      'cumin',
      'turmeric',
      'curry',
    ])) {
      return 'Herbs & Spices';
    }
    if (_containsAny(value, const <String>[
      'rice',
      'flour',
      'noodle',
      'bread',
      'sugar',
      'salt',
      'oil',
      'soy',
    ])) {
      return 'Staples';
    }
    if (_containsAny(value, const <String>[
      'pineapple',
      'lime',
      'lemon',
      'apple',
      'banana',
      'orange',
    ])) {
      return 'Fruits';
    }
    return 'Others';
  }

  bool _containsAny(String input, List<String> keywords) {
    for (final keyword in keywords) {
      if (input.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  String? _resolveIngredientImageUrl(RecipeIngredient item) {
    final direct = item.imageUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final nested = item.ingredient.imageUrl?.trim();
    if (nested != null && nested.isNotEmpty) {
      return nested;
    }
    return null;
  }

  void _clearIngredientSelection() {
    setState(() {
      _selectedIngredients.clear();
      _query = '';
      _resultsFuture = _allRecipesFuture;
    });
  }

  Widget _ingredientCard(_IngredientOption option) {
    final isSelected = _selectedIngredients.contains(option.name);
    final iconData = _ingredientIconFor(option.group);
    final imageUrl = option.imageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? const Color(0xFFE9F3ED) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            _onIngredientChipToggled(option.name, !isSelected);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFBFD6C7)
                    : const Color(0xFFE6E6E6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Appears in ${option.count} recipes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: isSelected
                          ? const Color(0xFFD7EBDC)
                          : const Color(0xFFEAEAEA),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    iconData,
                                    color: const Color(0xFF3F7A5F),
                                  );
                                },
                              )
                            : Icon(iconData, color: const Color(0xFF3F7A5F)),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3F7A5F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _ingredientIconFor(String group) {
    switch (group) {
      case 'Vegetables':
        return Icons.eco_outlined;
      case 'Meat & Seafood':
        return Icons.set_meal_outlined;
      case 'Dairy & Eggs':
        return Icons.egg_alt_outlined;
      case 'Herbs & Spices':
        return Icons.spa_outlined;
      case 'Sauces & Pastes':
        return Icons.soup_kitchen_outlined;
      case 'Staples':
        return Icons.rice_bowl_outlined;
      case 'Fruits':
        return Icons.apple_outlined;
      default:
        return Icons.kitchen_outlined;
    }
  }

  Widget _selectedIngredientChip(String name) {
    return InputChip(
      label: Text(
        name,
        style: TextStyle(
          color: Colors.green.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
      onDeleted: () {
        _onIngredientChipToggled(name, false);
      },
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: Colors.green.shade900,
      backgroundColor: Colors.green.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: Colors.green.shade300),
    );
  }

  Widget _ingredientGroupChip(_IngredientGroup group) {
    final isSelected = _selectedIngredientGroup == group.name;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          '${group.name} (${group.count})',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.green.shade900 : Colors.grey.shade800,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedIngredientGroup = group.name;
          });
        },
        selectedColor: Colors.green.shade300,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(
          color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      ),
    );
  }

  Widget _categoryChip(_CategoryFilter category) {
    final isSelected = _selectedCategoryName == category.id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(category.name),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryName = category.id;
          });
        },
        selectedColor: Colors.green.shade300,
        backgroundColor: Colors.green.shade100,
      ),
    );
  }

  Widget _recipeRow(BuildContext context, Recipe recipe) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailView(recipe: recipe)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
            boxShadow: [
            BoxShadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.08)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                recipe.imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.local_fire_department, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        recipe.calory?.toString() ?? 'N/A',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recipe.category.name,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter {
  const _CategoryFilter(this.id, this.name);

  final String? id;
  final String name;
}

class _IngredientOption {
  const _IngredientOption(this.name, this.count, this.group, this.imageUrl);

  final String name;
  final int count;
  final String group;
  final String? imageUrl;
}

class _IngredientGroup {
  const _IngredientGroup(this.name, this.count);

  final String name;
  final int count;
}
