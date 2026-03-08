import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/painters/skeleton_painter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorModeScrubbingScreen extends StatefulWidget {
  final List<List<Map<String, double>>> frames;
  final List<Map<String, double>> angles;

  const CreatorModeScrubbingScreen({
    super.key,
    required this.frames,
    required this.angles,
  });

  @override
  State<CreatorModeScrubbingScreen> createState() =>
      _CreatorModeScrubbingScreenState();
}

class _CreatorModeScrubbingScreenState
    extends State<CreatorModeScrubbingScreen> {
  int _currentFrame = 0;

  // List of keyframes: { 'name': String, 'frameIndex': int, 'holdTime': int, 'tolerance': double }
  final List<Map<String, dynamic>> _keyframes = [];

  final Set<String> _selectedJoints = {
    'leftElbow',
    'rightElbow',
    'leftHip',
    'rightHip',
    'leftKnee',
    'rightKnee',
    'leftShoulder',
    'rightShoulder',
  };

  final List<String> _availableJoints = [
    'leftElbow',
    'rightElbow',
    'leftShoulder',
    'rightShoulder',
    'leftHip',
    'rightHip',
    'leftKnee',
    'rightKnee',
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _velocityController = TextEditingController();
  final TextEditingController _keyframeNameController = TextEditingController();
  final TextEditingController _holdTimeController = TextEditingController(
    text: "0",
  );
  final TextEditingController _toleranceController = TextEditingController(
    text: "15.0",
  );
  String _exerciseType = 'Rep-based';

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _velocityController.dispose();
    _keyframeNameController.dispose();
    _holdTimeController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  void _addKeyframe() {
    final frameIdx = _currentFrame;
    final name = _keyframeNameController.text.trim();
    final holdTime = int.tryParse(_holdTimeController.text) ?? 0;
    final tolerance = double.tryParse(_toleranceController.text) ?? 15.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this keyframe')),
      );
      return;
    }

    setState(() {
      _keyframes.add({
        'name': name,
        'frameIndex': frameIdx,
        'holdTime': holdTime,
        'tolerance': tolerance,
        'activeJoints': Set<String>.from(_selectedJoints),
      });
      _keyframeNameController.clear();
      _holdTimeController.text = "0";
      _toleranceController.text = "15.0";
    });
  }

  void _removeKeyframe(int index) {
    setState(() {
      _keyframes.removeAt(index);
    });
  }

  Future<void> _exportAndSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name')),
      );
      return;
    }
    if (_keyframes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set at least 2 keyframes before saving.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final List<Map<String, dynamic>> statesArray = [];

      for (var kf in _keyframes) {
        final allAngles = widget.angles[kf['frameIndex'] as int];
        final Set<String> activeJoints = kf['activeJoints'] as Set<String>;

        // Filter map to only include selected joints
        final Map<String, double> filteredAngles = {};
        for (var joint in activeJoints) {
          if (allAngles.containsKey(joint)) {
            filteredAngles[joint] = allAngles[joint]!;
          }
        }

        statesArray.add({
          'stateName': kf['name'],
          'targetAngles': filteredAngles,
          'tolerance': kf['tolerance'] ?? 15.0,
          'holdTime': kf['holdTime'],
        });
      }

      final Map<String, dynamic> jsonPayload = {
        'exercise_name': _nameController.text.trim(),
        'exercise_type': _exerciseType,
        'velocity_requirement': _velocityController.text.isEmpty
            ? null
            : double.tryParse(_velocityController.text),
        'states': statesArray,
      };

      // Upsert to Supabase
      await Supabase.instance.client.from('workout_definitions').upsert({
        'exercise_name': _nameController.text.trim(),
        'definition_data': jsonPayload,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Supabase Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to original profile/home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty)
      return const Scaffold(body: Center(child: Text("No frames available")));

    final currentSkeleton = widget.frames[_currentFrame];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scrub & Define Logic',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Display the skeleton for the active frame
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: CustomPaint(
                painter: SkeletonPainter(currentSkeleton),
                size: Size.infinite,
              ),
            ),
          ),

          // Scrub bar
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Frame: $_currentFrame',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: Slider(
                            value: _currentFrame.toDouble(),
                            min: 0,
                            max: (widget.frames.length - 1).toDouble(),
                            divisions: widget.frames.length > 1
                                ? widget.frames.length - 1
                                : 1,
                            onChanged: (val) {
                              setState(() {
                                _currentFrame = val.toInt();
                              });
                            },
                          ),
                        ),
                        Text(
                          '${widget.frames.length - 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    // Keyframe management
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Add Keyframe at this Frame",
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Select Active Joints for this State:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: _availableJoints.map((joint) {
                              final isSelected = _selectedJoints.contains(
                                joint,
                              );
                              return FilterChip(
                                label: Text(
                                  joint
                                      .replaceAll('left', 'L ')
                                      .replaceAll('right', 'R '),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedJoints.add(joint);
                                    } else {
                                      if (_selectedJoints.length > 1) {
                                        _selectedJoints.remove(joint);
                                      }
                                    }
                                  });
                                },
                                backgroundColor: Colors.white10,
                                selectedColor: Colors.blueAccent.withOpacity(
                                  0.3,
                                ),
                                checkmarkColor: Colors.blueAccent,
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                padding: const EdgeInsets.all(0),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _keyframeNameController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: "State Name (e.g. Down)",
                                    hintStyle: TextStyle(color: Colors.grey),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _holdTimeController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: "Hold(s)",
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _toleranceController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    hintText: "Tol(°)",
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                ),
                                onPressed: _addKeyframe,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Keyframe List
                    if (_keyframes.isNotEmpty) ...[
                      const Text(
                        "Sequence of States",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _keyframes.length,
                        itemBuilder: (context, index) {
                          final kf = _keyframes[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                "${index + 1}. ${kf['name']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Frame: ${kf['frameIndex']} | Hold: ${kf['holdTime']}s | Tol: ${kf['tolerance']}°",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _removeKeyframe(index),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name',
                        labelStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Color(0xFF2C313A),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Type:',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _exerciseType,
                          dropdownColor: const Color(0xFF2C313A),
                          style: const TextStyle(color: Colors.white),
                          items: ['Rep-based', 'Hold-based']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _exerciseType = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _velocityController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min Velocity (Optional)',
                        labelStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Color(0xFF2C313A),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _exportAndSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save to Workspace',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
