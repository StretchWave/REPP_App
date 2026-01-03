import 'package:ai_fitness_tracker/services/diet_service.dart';
import 'package:flutter/material.dart';

class MealSelectionScreen extends StatefulWidget {
  const MealSelectionScreen({super.key});

  @override
  State<MealSelectionScreen> createState() => _MealSelectionScreenState();
}

class _MealSelectionScreenState extends State<MealSelectionScreen> {
  final DietService _dietService = DietService();
  final TextEditingController _searchController = TextEditingController();
  List<FoodLog> _recentMeals = [];
  List<FoodLog> _filteredMeals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterMeals);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final meals = await _dietService.getRecentMeals();
    if (mounted) {
      setState(() {
        _recentMeals = meals;
        _filteredMeals = meals;
        _isLoading = false;
      });
    }
  }

  void _filterMeals() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMeals = _recentMeals;
      } else {
        _filteredMeals = _recentMeals
            .where((meal) => meal.foodName.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _onMealSelected(FoodLog meal) {
    // Return the selected meal details to the previous screen
    Navigator.pop(context, {
      'name': meal.foodName,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fats': meal.fats,
    });
  }

  Future<void> _deleteMeal(FoodLog meal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Meal"),
        content: const Text("Remove this meal from your history?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dietService.deleteFoodLog(meal.id);
      _loadHistory(); // Refresh
    }
  }

  Future<void> _editMeal(FoodLog meal) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMealDialog(
        initialName: meal.foodName,
        initialCalories: meal.calories,
        initialProtein: meal.protein,
        initialCarbs: meal.carbs,
        initialFats: meal.fats,
      ),
    );

    if (result != null) {
      // If editing an existing history item, we update it
      // Note: This changes history!
      await _dietService.updateFoodLog(
        id: meal.id,
        foodName: result['name'],
        calories: result['calories'],
        protein: result['protein'],
        carbs: result['carbs'],
        fats: result['fats'],
      );
      _loadHistory();
    }
  }

  Future<void> _addNewMeal() async {
    // Open the same dialog logic, but here.
    // We can reuse the dialog widget if we make it public or duplicate strictly needed parts.
    // For cleaner code, let's return a "addNew" signal or handle it here.
    // The user wants the + button here.

    // We can pop with a specific flag or just open the dialog here.
    // Let's open the dialog here.
    // Ideally _AddMealDialog should be a public widget.
    // For now I will ask the caller (DietScreen) to handle "addNew" if I return null?
    // User said: "at the bottom right corner add a plus button to add a new meal"
    // It's better if this screen handles the input and returns the FINAL data.

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddMealDialog(),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Select Meal",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search meals...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMeals.isEmpty
                ? Center(
                    child: Text(
                      _recentMeals.isEmpty
                          ? "No recent meals found.\nAdd your first one!"
                          : "No meals match your search.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredMeals.length,
                    itemBuilder: (context, index) {
                      final meal = _filteredMeals[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            meal.foodName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            "${meal.calories} kcal • P:${meal.protein} C:${meal.carbs} F:${meal.fats}",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editMeal(meal);
                              if (value == 'delete') _deleteMeal(meal);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Edit"),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Delete"),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                          ),
                          onTap: () => _onMealSelected(meal),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewMeal,
        backgroundColor: const Color(0xFF1E2126),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Moved the dialog here or made it shared?
// For now, I will define a public AddMealDialog here to be used by this screen.
// I will need to update Diet.dart to remove the private _AddMealDialog or use this one.
class AddMealDialog extends StatefulWidget {
  final String? initialName;
  final int? initialCalories;
  final double? initialProtein;
  final double? initialCarbs;
  final double? initialFats;

  const AddMealDialog({
    super.key,
    this.initialName,
    this.initialCalories,
    this.initialProtein,
    this.initialCarbs,
    this.initialFats,
  });

  @override
  State<AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<AddMealDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _calController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _calController = TextEditingController(
      text: widget.initialCalories?.toString() ?? '',
    );
    _proteinController = TextEditingController(
      text: widget.initialProtein?.toString() ?? '',
    );
    _carbsController = TextEditingController(
      text: widget.initialCarbs?.toString() ?? '',
    );
    _fatsController = TextEditingController(
      text: widget.initialFats?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? "Add New Meal" : "Edit Meal"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Food Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _calController,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              const Text(
                "Macros (Optional)",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(labelText: 'P (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(labelText: 'C (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _fatsController,
                      decoration: const InputDecoration(labelText: 'F (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final p = double.tryParse(_proteinController.text.trim()) ?? 0.0;
              final c = double.tryParse(_carbsController.text.trim()) ?? 0.0;
              final f = double.tryParse(_fatsController.text.trim()) ?? 0.0;

              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'calories': int.parse(_calController.text.trim()),
                'protein': p,
                'carbs': c,
                'fats': f,
              });
            }
          },
          child: Text(widget.initialName == null ? "Add" : "Save"),
        ),
      ],
    );
  }
}
