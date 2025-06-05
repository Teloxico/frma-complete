// lib/pages/health_metrics_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/drawer_menu.dart';

class HealthMetricsPage extends StatelessWidget {
  const HealthMetricsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Metrics'),
        elevation: 2.0,
      ),
      drawer: const DrawerMenu(currentRoute: '/health_metrics'),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, _) {
          return _buildMetricsBody(context, profileProvider);
        },
      ),
    );
  }

  Widget _buildMetricsBody(
      BuildContext context, ProfileProvider profileProvider) {
    final bool hasData = profileProvider.name.isNotEmpty ||
        profileProvider.age != null ||
        profileProvider.weight > 0 ||
        profileProvider.height > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(context, profileProvider),
          const SizedBox(height: 16),
          if (profileProvider.height > 0 || profileProvider.weight > 0)
            _buildMetricsOverview(context, profileProvider),
          if (profileProvider.bmi != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildBmiCard(context, profileProvider),
            ),
          if (hasData) ...[
            const SizedBox(height: 16),
            _buildMedicalConditionsCard(context, profileProvider),
            const SizedBox(height: 16),
            _buildAllergiesCard(context, profileProvider),
            const SizedBox(height: 16),
            _buildMedicationsCard(context, profileProvider),
          ] else ...[
            _buildNoDataCard(context),
          ],
          const SizedBox(height: 24),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, ProfileProvider profileProvider) {
    final bool hasData =
        profileProvider.name.isNotEmpty || profileProvider.age != null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: hasData
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      profileProvider.name.isNotEmpty
                          ? profileProvider.name[0].toUpperCase()
                          : "?",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profileProvider.name.isNotEmpty
                              ? profileProvider.name
                              : "Profile",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (profileProvider.age != null)
                          Text(
                            '${profileProvider.age} years old',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        if (profileProvider.gender.isNotEmpty)
                          Text(
                            profileProvider.gender,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No profile data available',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricsOverview(
      BuildContext context, ProfileProvider profileProvider) {
    final bool hasHeight = profileProvider.height > 0;
    final bool hasWeight = profileProvider.weight > 0;
    final bool hasBloodType = profileProvider.bloodType.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Key Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (hasWeight)
                  _buildMetricItem(
                    context: context,
                    icon: Icons.monitor_weight,
                    value: '${profileProvider.weight}',
                    unit: 'kg',
                    label: 'Weight',
                  ),
                if (hasHeight)
                  _buildMetricItem(
                    context: context,
                    icon: Icons.height,
                    value: '${profileProvider.height}',
                    unit: 'cm',
                    label: 'Height',
                  ),
                if (hasBloodType)
                  _buildMetricItem(
                    context: context,
                    icon: Icons.bloodtype,
                    value: profileProvider.bloodType,
                    unit: '',
                    label: 'Blood',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String unit,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: unit.isNotEmpty ? ' $unit' : '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBmiCard(BuildContext context, ProfileProvider profileProvider) {
    if (profileProvider.bmi == null) {
      return const SizedBox.shrink();
    }

    final double bmi = profileProvider.bmi!;
    final String category = profileProvider.bmiCategory;
    final Color categoryColor = _getBmiColor(category);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: categoryColor),
                const SizedBox(width: 8),
                const Text(
                  'Body Mass Index (BMI)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: categoryColor.withOpacity(0.2),
                    border: Border.all(
                      color: categoryColor,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                      Text(
                        'BMI',
                        style: TextStyle(
                          fontSize: 14,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getBmiDescription(category),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBmiScaleIndicator(context, bmi)
          ],
        ),
      ),
    );
  }

  Widget _buildBmiScaleIndicator(BuildContext context, double bmi) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: Stack(
        children: [
          // BMI Scale
          Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [
                  Colors.blue, // Underweight
                  Colors.green, // Normal
                  Colors.orange, // Overweight
                  Colors.red, // Obese
                ],
              ),
            ),
          ),

          // BMI Indicator
          Positioned(
            left: (bmi / 40 * MediaQuery.of(context).size.width * 0.85)
                .clamp(0, MediaQuery.of(context).size.width - 40),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getBmiColor(_getBmiCategory(bmi)),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // Scale labels
          Positioned(
            top: 22,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('18.5', style: TextStyle(fontSize: 10)),
                Text('25', style: TextStyle(fontSize: 10)),
                Text('30', style: TextStyle(fontSize: 10)),
                Text('40', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalConditionsCard(
      BuildContext context, ProfileProvider profileProvider) {
    final hasConditions =
        profileProvider.medicalConditions.any((c) => c.selected);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_information,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Medical Conditions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            hasConditions
                ? Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: profileProvider.medicalConditions
                        .where((c) => c.selected)
                        .map((condition) => Chip(
                              avatar: const Icon(
                                Icons.medical_services,
                                size: 16,
                                color: Colors.white,
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              label: Text(
                                condition.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ))
                        .toList(),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'No medical conditions specified',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergiesCard(
      BuildContext context, ProfileProvider profileProvider) {
    final hasAllergies = profileProvider.allergies.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.sick, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Allergies',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            hasAllergies
                ? Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: profileProvider.allergies
                        .map((allergy) => Chip(
                              avatar: const Icon(
                                Icons.dangerous,
                                size: 16,
                                color: Colors.white,
                              ),
                              backgroundColor: Colors.red,
                              label: Text(
                                allergy,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ))
                        .toList(),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'No allergies specified',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsCard(
      BuildContext context, ProfileProvider profileProvider) {
    final hasMedications = profileProvider.medications.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.medication, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Current Medications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            hasMedications
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: profileProvider.medications.length,
                    itemBuilder: (context, index) {
                      final medication = profileProvider.medications[index];
                      return Card(
                        elevation: 0,
                        color: Colors.orange.withOpacity(0.1),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.medication_outlined,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medication.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${medication.dosage} - ${medication.frequency}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'No medications specified',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No health metrics available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Health information will be displayed here once it\'s added to your profile',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Disclaimer: This information is for personal reference only. Always consult with a healthcare professional for medical advice.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBmiColor(String category) {
    switch (category) {
      case 'Underweight':
        return Colors.blue;
      case 'Normal':
        return Colors.green;
      case 'Overweight':
        return Colors.orange;
      case 'Obese':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String _getBmiDescription(String category) {
    switch (category) {
      case 'Underweight':
        return 'BMI less than 18.5. May indicate nutritional deficiency.';
      case 'Normal':
        return 'BMI between 18.5 and 24.9. Healthy weight range.';
      case 'Overweight':
        return 'BMI between 25 and 29.9. May increase health risks.';
      case 'Obese':
        return 'BMI of 30 or higher. Associated with increased health risks.';
      default:
        return '';
    }
  }
}
