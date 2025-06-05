// lib/widgets/feature_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

/// A reusable card-like tile for displaying features on the home page grid.
class FeatureTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap; // Action to perform when tapped

  const FeatureTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Note: isDark is defined but not used in this version, can be removed if not needed.
    // final isDark = theme.brightness == Brightness.dark;

    return Card(
      // Use Card for consistent styling (elevation, shape) across tiles.
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip
          .antiAlias, // Ensures InkWell splash stays within rounded corners.
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact(); // Provide subtle feedback on tap.
          onTap(); // Execute the provided tap action.
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Center content vertically
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center content horizontally
            children: [
              // Circular background for the icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      color.withOpacity(0.15), // Use tile's color with opacity
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color, // Use tile's color for the icon itself
                ),
              ),
              const SizedBox(height: 12),
              // Feature title text
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, // Make title slightly bolder
                ),
                textAlign: TextAlign.center, // Center align title
                maxLines: 2, // Allow title to wrap onto two lines if needed
                overflow:
                    TextOverflow.ellipsis, // Use ellipsis if text is too long
              ),
            ],
          ),
        ),
      ),
    );
  }
}
