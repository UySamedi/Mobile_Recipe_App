import 'package:flutter/material.dart';

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
  final TextEditingController _ingredientFilterController =
      TextEditingController();
  String _query = '';
  String _ingredientFilterQuery = '';
  int? _selectedCategoryId;
  String _selectedIngredientGroup = _ingredientGroupAll;
  final Set<String> _selectedIngredients = <String>{};
  List<Recipe> _allRecipesCache = const <Recipe>[];

  @override
  void initState() {
    super.initState();
    _refreshAllRecipes(updateResults: true);
  }

  @override
  void dispose() {
    _ingredientFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
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
    final categories = _buildCategories(recipes);
    if (_selectedCategoryId != null &&
        !categories.any((category) => category.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }
    final filtered = _filterByCategory(recipes, _selectedCategoryId);
    final results = _sortByRating(filtered);
    final ingredientOptions = _buildIngredientOptions(
      _allRecipesCache.isEmpty ? recipes : _allRecipesCache,
    );
    final ingredientGroups = _buildIngredientGroups(ingredientOptions);
    if (!ingredientGroups.any((group) => group.name == _selectedIngredientGroup)) {
      _selectedIngredientGroup = _ingredientGroupAll;
    }
    final visibleIngredientOptions = _filterIngredientOptionsByGroup(
      ingredientOptions,
      _selectedIngredientGroup,
    );
    final filteredIngredientOptions = _filterIngredientOptionsByText(
      visibleIngredientOptions,
      _ingredientFilterQuery,
    );

    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ingredientOptions.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedIngredients.isEmpty
                      ? 'Tap ingredients to build your search'
                      : '${_selectedIngredients.length} selected',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedIngredients.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedIngredients
                        .map(_selectedIngredientChip)
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _ingredientFilterController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Filter ingredient chips',
                    prefixIcon: const Icon(Icons.tune, size: 18),
                    suffixIcon: _ingredientFilterQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _ingredientFilterQuery = '';
                                _ingredientFilterController.clear();
                              });
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.green.shade100),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.green.shade100),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _ingredientFilterQuery = value.trim();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ingredientGroups
                        .map(_ingredientGroupChip)
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 10),
                if (filteredIngredientOptions.isEmpty)
                  Text(
                    'No ingredients match this filter.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filteredIngredientOptions.map((option) {
                      final selected = _selectedIngredients.contains(option.name);
                      return FilterChip(
                        label: Text(
                          '${option.name} (${option.count})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        onSelected: (value) {
                          _onIngredientChipToggled(option.name, value);
                        },
                        selectedColor: Colors.green.shade200,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? Colors.green.shade500
                              : Colors.grey.shade300,
                        ),
                        checkmarkColor: Colors.green.shade900,
                      );
                    }).toList(growable: false),
                  ),
                if (_selectedIngredients.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _clearIngredientSelection,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear selected ingredients'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade900,
                    ),
                  ),
                ],
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
          _query.trim().isEmpty
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
            sliver: SliverToBoxAdapter(
              child: topSection,
            ),
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: 12);
                    }
                    final recipe = results[index ~/ 2];
                    return _recipeRow(context, recipe);
                  },
                  childCount: results.isEmpty ? 0 : results.length * 2 - 1,
                ),
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

  void _runSearch() {
    final names = _parseIngredients(_query);
    setState(() {
      _resultsFuture =
          names.isEmpty ? _allRecipesFuture : RecipeApi.searchByIngredients(names);
    });
  }

  void _onIngredientChipToggled(String name, bool selected) {
    setState(() {
      if (selected) {
        _selectedIngredients.add(name);
      } else {
        _selectedIngredients.remove(name);
      }
      _selectedCategoryId = null;
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

  List<_CategoryFilter> _buildCategories(List<Recipe> recipes) {
    final Map<int, String> byId = {};
    for (final recipe in recipes) {
      byId.putIfAbsent(recipe.category.id, () => recipe.category.name);
    }
    final entries = byId.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      const _CategoryFilter(null, 'All'),
      ...entries.map((entry) => _CategoryFilter(entry.key, entry.value)),
    ];
  }

  List<Recipe> _filterByCategory(List<Recipe> recipes, int? selectedId) {
    if (selectedId == null) {
      return recipes;
    }
    return recipes.where((recipe) => recipe.category.id == selectedId).toList();
  }

  List<Recipe> _sortByRating(List<Recipe> recipes) {
    final sorted = [...recipes]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  List<_IngredientOption> _buildIngredientOptions(List<Recipe> recipes) {
    final Map<String, int> counts = {};
    for (final recipe in recipes) {
      for (final item in recipe.ingredients) {
        final name = item.ingredient.name.trim();
        if (name.isEmpty) {
          continue;
        }
        counts.update(name, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final options = counts.entries
        .map(
          (entry) => _IngredientOption(
            entry.key,
            entry.value,
            _classifyIngredientGroup(entry.key),
          ),
        )
        .toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.name.compareTo(b.name);
      });
    const maxChips = 18;
    if (options.length <= maxChips) {
      return options;
    }
    return options.sublist(0, maxChips);
  }

  List<_IngredientGroup> _buildIngredientGroups(List<_IngredientOption> options) {
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
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return options;
    }
    return options
        .where((option) => option.name.toLowerCase().contains(trimmed))
        .toList();
  }

  String _classifyIngredientGroup(String ingredientName) {
    final value = ingredientName.toLowerCase();

    if (_containsAny(value, const <String>['sauce', 'paste', 'ketchup', 'mayo'])) {
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

  void _clearIngredientSelection() {
    setState(() {
      _selectedIngredients.clear();
      _query = '';
      _resultsFuture = _allRecipesFuture;
    });
  }

  Widget _selectedIngredientChip(String name) {
    return InputChip(
      label: Text(name),
      onDeleted: () {
        _onIngredientChipToggled(name, false);
      },
      deleteIcon: const Icon(Icons.close, size: 16),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.green.shade200),
    );
  }

  Widget _ingredientGroupChip(_IngredientGroup group) {
    final isSelected = _selectedIngredientGroup == group.name;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('${group.name} (${group.count})'),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedIngredientGroup = group.name;
          });
        },
        selectedColor: Colors.green.shade300,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _categoryChip(_CategoryFilter category) {
    final isSelected = _selectedCategoryId == category.id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(category.name),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = category.id;
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
          MaterialPageRoute(
            builder: (_) => RecipeDetailView(recipe: recipe),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withOpacity(0.08),
            ),
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

  final int? id;
  final String name;
}

class _IngredientOption {
  const _IngredientOption(this.name, this.count, this.group);

  final String name;
  final int count;
  final String group;
}

class _IngredientGroup {
  const _IngredientGroup(this.name, this.count);

  final String name;
  final int count;
}
