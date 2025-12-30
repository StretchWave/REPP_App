import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/FitnessGoal.dart';

class PersonalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> signUpData;
  const PersonalDetailsScreen({super.key, required this.signUpData});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  // Controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // State Variables
  String _selectedGender = 'Male';
  bool _medicalConditions = false;
  // bool _doctorRestricted = false; // Removed
  bool _canFocusUpperBody = false;
  bool _canFocusLowerBody = false;
  String? _selectedBodyType;

  final Map<String, String> _bodyTypeDescriptions = {
    'Ectomorph': 'More rest, higher calories, strength focus',
    'Mesomorph': 'Balanced training',
    'Endomorph': 'Higher reps, cardio volume, shorter rest',
  };

  void _onContinue() {
    // Collect Current Data
    final personalData = {
      'age': _ageController.text.trim(),
      'gender': _selectedGender,
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
      'physically_handicapped': _medicalConditions,
      'can_focus_upper_body': _medicalConditions ? _canFocusUpperBody : true,
      'can_focus_lower_body': _medicalConditions ? _canFocusLowerBody : true,
      'body_type': _selectedBodyType,
    };

    // Merge with previous data
    final mergedData = {...widget.signUpData, ...personalData};

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FitnessGoalsScreen(previousData: mergedData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF485563), // Dark background behind card
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header Overlay
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Body Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Help us personalize your fitness journey',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: LinearProgressIndicator(
                    value: 0.3, // Step 1/3 approx
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),

          // White Card Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildLabel('Age', isRequired: true),
                  _buildTextField(
                    _ageController,
                    'Enter your age',
                    suffix: 'years',
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Gender', isRequired: true),
                  Row(
                    children: [
                      Expanded(child: _buildGenderSelector('Male', '👨')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildGenderSelector('Female', '👩')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Height', isRequired: true),
                  _buildTextField(
                    _heightController,
                    'Enter your height',
                    suffix: 'cm',
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Weight', isRequired: true),
                  _buildTextField(
                    _weightController,
                    'Enter your weight',
                    suffix: 'kg',
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 24),

                  _buildLabel('Physically handicapped?', isRequired: true),
                  _buildYesNoSelector(
                    _medicalConditions,
                    (val) => setState(() => _medicalConditions = val),
                  ),

                  if (_medicalConditions) ...[
                    const SizedBox(height: 20),
                    _buildLabel('Which muscle groups can you focus on?'),
                    _buildCheckbox(
                      'Upper Body (Arms, Shoulder, Chest, Back)',
                      _canFocusUpperBody,
                      (val) {
                        setState(() => _canFocusUpperBody = val ?? false);
                      },
                    ),
                    _buildCheckbox('Lower Body (Legs)', _canFocusLowerBody, (
                      val,
                    ) {
                      setState(() => _canFocusLowerBody = val ?? false);
                    }),
                  ],
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _buildLabel('Body Type (Somatotype)'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OPTIONAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildBodyTypeCard('Ectomorph', '🏃'),
                      const SizedBox(width: 12),
                      _buildBodyTypeCard('Mesomorph', '💪'),
                      const SizedBox(width: 12),
                      _buildBodyTypeCard('Endomorph', '🧸'),
                    ],
                  ),
                  if (_selectedBodyType != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Text(
                        _bodyTypeDescriptions[_selectedBodyType]!,
                        style: TextStyle(color: Colors.blue[900], fontSize: 13),
                      ),
                    ),
                  ],
                  _buildHelperText(
                    "This helps us customize your workout and diet plan",
                  ),

                  const SizedBox(height: 48),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('← Back'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF6C757D,
                            ), // Dark Grey button
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Continue →'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C757D),
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.all(14.0),
                child: Text(
                  suffix,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildHelperText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildGenderSelector(String gender, String icon) {
    bool isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.grey[600]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.white : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              gender,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYesNoSelector(bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: value ? Colors.grey[600]! : Colors.grey[300]!,
                  width: value ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Yes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: value ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: !value ? Colors.grey[600]! : Colors.grey[300]!,
                  width: !value ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: !value ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyTypeCard(String type, String icon) {
    bool isSelected = _selectedBodyType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBodyType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.grey[600]! : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                type,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF6C757D),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
