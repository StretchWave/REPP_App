import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_tracker/screens/execute_workout_screen.dart';

class WorkoutLibraryScreen extends StatefulWidget {
  const WorkoutLibraryScreen({super.key});

  @override
  State<WorkoutLibraryScreen> createState() => _WorkoutLibraryScreenState();
}

class _WorkoutLibraryScreenState extends State<WorkoutLibraryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _workouts = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  Future<void> _fetchWorkouts() async {
    try {
      final response = await _supabase
          .from('workout_definitions')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _workouts = response as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching workouts: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load workouts: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2126),
      appBar: AppBar(
        title: const Text(
          'Creator Library',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _workouts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                final data = workout['definition_data'] as Map<String, dynamic>;
                final name = workout['exercise_name'] ?? "Unknown Exercise";
                final type = data['exercise_type'] ?? "Rep-based";
                final stateCount = (data['states'] as List?)?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C313A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$type • $stateCount Stages",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        if (workout['is_approved'] == true)
                          Text(
                            "APPROVED • Unlocks Level ${workout['unlock_power_level'] ?? 1}",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () => _showApprovalDialog(workout),
                        ),
                        const Icon(
                          Icons.play_circle_fill,
                          color: Colors.blueAccent,
                          size: 40,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExecuteWorkoutScreen(workoutDefinition: data),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showApprovalDialog(Map<String, dynamic> workout) async {
    bool isApproved = workout['is_approved'] ?? false;
    final powerLevelController = TextEditingController(
      text: (workout['unlock_power_level'] ?? 1).toString(),
    );
    final baseRepsController = TextEditingController(
      text: (workout['base_reps'] ?? 10).toString(),
    );
    final multiplierController = TextEditingController(
      text: (workout['rep_multiplier'] ?? 1.0).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C313A),
          title: Text(
            "Manage ${workout['exercise_name']}",
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text(
                    "Is Approved?",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: isApproved,
                  onChanged: (val) => setDialogState(() => isApproved = val),
                ),
                TextField(
                  controller: powerLevelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Unlock Power Level",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: baseRepsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Base Reps",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: multiplierController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Rep Multiplier (per level)",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _supabase
                      .from('workout_definitions')
                      .update({
                        'is_approved': isApproved,
                        'unlock_power_level': int.parse(
                          powerLevelController.text,
                        ),
                        'base_reps': int.parse(baseRepsController.text),
                        'rep_multiplier': double.parse(
                          multiplierController.text,
                        ),
                      })
                      .eq('id', workout['id']);

                  if (mounted) {
                    Navigator.pop(context);
                    _fetchWorkouts();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Format error: $e")));
                }
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No custom workouts found.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Go to Creator Mode to add one!",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
