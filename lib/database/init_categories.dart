import 'package:flutter/foundation.dart';
import 'database.dart';

// Structure to hold category information
class CategoryInfo {
  final String name;
  final String asset;
  
  CategoryInfo(this.name, this.asset);
}

class CategoryInitializer {
  // Add your new categories to this list to automatically add them to the database
  static final List<CategoryInfo> defaultCategories = [
    CategoryInfo('Business & Consulting', 'business'),
    CategoryInfo('Education & Tutoring', 'edu'),
    CategoryInfo('Writing & Editing', 'writing'),
    // You can add more categories here in the future
  ];
  
  // This function should be called at app startup
  static Future<void> ensureCategoriesExist() async {
    try {
      // Get existing categories
      final existingCategories = await DatabaseHelper.fetchCategories();
      final existingNames = existingCategories.map((cat) => cat['name'] as String).toSet();
      
      // Check which categories need to be added
      final categoriesToAdd = defaultCategories.where(
        (cat) => !existingNames.contains(cat.name)
      ).toList();
      
      // Add missing categories
      for (final category in categoriesToAdd) {
        debugPrint('Adding new category: ${category.name}');
        
        final result = await DatabaseHelper.createCategory(
          category.name, 
          category.asset
        );
        
        if (result.success) {
          debugPrint('Successfully added category: ${category.name}');
        } else {
          debugPrint('Failed to add category: ${category.name} - ${result.data['error']}');
        }
      }
      
      if (categoriesToAdd.isEmpty) {
        debugPrint('All categories already exist in the database');
      } else {
        debugPrint('Added ${categoriesToAdd.length} new categories');
      }
    } catch (e) {
      debugPrint('Error initializing categories: $e');
    }
  }
} 