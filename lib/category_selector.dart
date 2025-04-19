// lib/category_selector.dart
import 'package:flutter/material.dart';

class CategorySelector extends StatelessWidget {
  // StatelessWidget is good
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final bool isLoading;

  const CategorySelector({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.isLoading = false, // Prop for parent control
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Rely on ChipTheme defined in main.dart
    // (Removed explicit color definitions as theme should handle this)

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : (categories.isEmpty // Handle case where categories might be empty
              ? Center(
                  child:
                      Text('No categories', style: theme.textTheme.bodySmall))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = category == selectedCategory;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) => onCategorySelected(category),
                        tooltip: 'Set category to $category',
                        // Explicitly use theme styles/colors if needed, but often implicit is fine
                        // backgroundColor: theme.chipTheme.backgroundColor,
                        // selectedColor: theme.chipTheme.selectedColor,
                        // labelStyle: isSelected
                        //    ? theme.chipTheme.secondaryLabelStyle
                        //    : theme.chipTheme.labelStyle, // <<< COMPLETE EXAMPLE if needed
                      ),
                    );
                  },
                )),
    );
  }
}
