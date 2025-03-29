import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;
  
  // Get a user from their ID
  static Future<Map<String, dynamic>> getUserFromId(String userId) async {
    try {
      if (userId.isEmpty) {
        print('Error: userID is null or empty');
        return {};
      }
      
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response ?? {};
    } catch (e) {
      print('Error getting user from id: $e');
      return {};
    }
  }
  
  // Search for users by username
  static Future<List<Map<String, dynamic>>> searchUsers(String search) async {
    if (search.isEmpty) {
      return [];
    }
    
    try {
      final response = await client
          .from('users')
          .select()
          .ilike('username', '%$search%')
          .limit(20);
      
      return response;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
  
  // Search for skills with filtering and sorting
  static Future<List<Map<String, dynamic>>> searchSkills(
    String query, {
    String? category,
    int? minPrice,
    int? maxPrice,
    String? sortBy,
  }) async {
    try {
      // Use a simpler query approach to avoid type issues
      var response = await client.from('skills').select();
      
      // Manual filtering
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);
      
      // Apply text search if query is provided
      if (query.isNotEmpty) {
        results = results.where((skill) => 
          (skill['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase()) ||
          (skill['description'] ?? '').toString().toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
      
      // Apply category filter if provided
      if (category != null && category.isNotEmpty) {
        results = results.where((skill) => 
          skill['category'] == category
        ).toList();
      }
      
      // Apply price filters if provided
      if (minPrice != null) {
        results = results.where((skill) => 
          (skill['cost'] ?? 0) >= minPrice
        ).toList();
      }
      
      if (maxPrice != null) {
        results = results.where((skill) => 
          (skill['cost'] ?? 0) <= maxPrice
        ).toList();
      }
      
      // Apply sorting
      if (sortBy != null) {
        switch(sortBy) {
          case 'recent':
            results.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
            break;
          case 'price_asc':
            results.sort((a, b) => (a['cost'] ?? 0).compareTo(b['cost'] ?? 0));
            break;
          case 'price_desc':
            results.sort((a, b) => (b['cost'] ?? 0).compareTo(a['cost'] ?? 0));
            break;
        }
      } else {
        // Default sorting by recently created
        results.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
      }
      
      return results;
    } catch (e) {
      print('Error searching skills: $e');
      return [];
    }
  }
  
  // Get skills by user ID
  static Future<List<Map<String, dynamic>>> getUserSkills({String? userId}) async {
    try {
      if (userId == null || userId.isEmpty) {
        print('No user ID available for getUserSkills');
        return [];
      }
      
      print('Fetching skills for user ID: $userId');
      final response = await client
          .from('skills')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      print('Retrieved ${response.length} skills for user $userId');
      return response;
    } catch (e) {
      print('Error getting user skills: $e');
      return [];
    }
  }
} 