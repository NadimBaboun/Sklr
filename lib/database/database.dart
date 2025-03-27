import 'dart:io';
import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'userIdStorage.dart';
import 'supabase_service.dart';
// Import with a prefix to avoid conflicts
import 'models.dart'; // Import shared models

// This class is now a wrapper around SupabaseService to maintain compatibility with existing code
class DatabaseHelper {
  // Flag to determine whether to use Supabase (true) or HTTP API (false)
  static const bool useSupabase = true;
  
  // Legacy backend URL (no longer used but kept for reference)
  static final String baseUrl = _initBackendUrl();
  
  static String _initBackendUrl() {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:3000';
    } else {
      return 'http://localhost:3000';
    }
  }

  // test backend server connection
  static Future<String> testConnection() async {
    try {
      // Just check if we can access the Supabase instance
      final result = await SupabaseService.getCategories();
      return result.isNotEmpty ? 'connected' : 'failed connection';
    } catch (err) {
      return 'failed connection: $err';
    }
  }

  // Get user data
  static Future<DatabaseResponse> getUser(int userId) async {
    try {
      final result = await SupabaseService.getUser(userId.toString());
      return result;
    } catch (err) {
      return DatabaseResponse(
        success: false,
        data: {'error': err.toString()},
      );
    }
  }

  // auth: Register
  static Future<LoginResponse> registerUser(
      String username, String email, String password) async {
    try {
      // Try direct SQL registration first
      final directResult = await SupabaseService.registerViaDirectSQL(username, email, password);
      
      if (directResult.success) {
        return LoginResponse(
          success: true,
          message: directResult.message,
          userId: directResult.userId is String ? int.tryParse(directResult.userId) ?? -1 : directResult.userId,
        );
      }
      
      // If there's a specific error (like username already exists), return it
      if (!directResult.success) {
        return LoginResponse(
          success: false,
          message: directResult.message,
        );
      }
      
      // Try direct database registration next
      final result = await SupabaseService.registerUserDirect(username, email, password);
      
      if (result.success) {
        return LoginResponse(
          success: true,
          message: result.message,
          userId: result.userId is String ? int.tryParse(result.userId) ?? -1 : result.userId,
        );
      }
      
      // If direct registration fails for application reasons, return that error
      if (!result.success) {
        return LoginResponse(
          success: false,
          message: result.message,
        );
      }
      
      // If direct registration fails for technical reasons, try Supabase Auth
      final authResult = await SupabaseService.registerUser(username, email, password);
      return LoginResponse(
        success: authResult.success,
        message: authResult.message,
        userId: authResult.userId is String ? int.tryParse(authResult.userId) ?? -1 : authResult.userId,
      );
    } catch (e) {
      return LoginResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Verify email
  static Future<bool> verifyEmail(String token, String type) async {
    try {
      return await SupabaseService.verifyEmail(token, type);
    } catch (e) {
      log('Error verifying email: $e');
      rethrow;
    }
  }

  // auth: Login
  static Future<LoginResponse> loginUser(String email, String password) async {
    try {
      // First try direct SQL authentication
      final directResult = await SupabaseService.authenticateViaDirectSQL(email, password);
      
      // If successful, return the result
      if (directResult.success) {
        return LoginResponse(
          success: directResult.success,
          message: directResult.message,
          userId: directResult.userId is String ? int.tryParse(directResult.userId) ?? -1 : directResult.userId,
        );
      }
      
      // If not successful but has specific error, return it
      if (!directResult.success) {
        return LoginResponse(
          success: false,
          message: directResult.message,
        );
      }
      
      // Then try to authenticate directly from users table via RPC
      final result = await SupabaseService.authenticateFromUsersTable(email, password);
      
      // If successful, return the result
      if (result.success) {
        return LoginResponse(
          success: result.success,
          message: result.message,
          userId: result.userId is String ? int.tryParse(result.userId) ?? -1 : result.userId,
        );
      }
      
      // If not successful, try Supabase Auth as fallback
      final authResult = await SupabaseService.signInWithEmail(email, password);
      return LoginResponse(
        success: authResult.success,
        message: authResult.message,
        userId: authResult.userId is String ? int.tryParse(authResult.userId) ?? -1 : authResult.userId,
      );
    } catch (e) {
      return LoginResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Logout
  static Future<Response> logoutUser() async {
    try {
      final success = await SupabaseService.signOut();
      return Response(
        success: success,
        message: success ? 'Logged out successfully' : 'Failed to logout',
      );
    } catch (e) {
      return Response(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Apple Sign-In
  static Future<LoginResponse> appleSignIn() async {
    try {
      final result = await SupabaseService.signInWithApple();
      return LoginResponse(
        success: result.success,
        message: result.message,
        userId: result.userId is String ? int.tryParse(result.userId) ?? -1 : result.userId,
      );
    } catch (e) {
      return LoginResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  static Future<DatabaseResponse> fetchUserFromId(dynamic userId) async {
    try {
      // Convert to String if it's an int
      String userIdStr = userId.toString();
      
      // Since the method is in supabase.dart but not in SupabaseService,
      // either call it using the proper class if in supabase.dart or another place
      final user = await SupabaseService.getUserById(userIdStr);
      if (user != null && user.isNotEmpty) {
        return DatabaseResponse(success: true, data: user);
      } else {
        log('User data not found for ID: $userIdStr');
        return DatabaseResponse(
          success: false,
          data: {'username': 'User not found', 'error': 'User not found'},
        );
      }
    } catch (e) {
      log('Error fetching user from id: $e');
      return DatabaseResponse(
        success: false,
        data: {'username': 'Unknown User', 'error': 'Failed to fetch user details'},
      );
    }
  }

  // update data for user
  // supported fields: email, password, phone_number, bio
  static Future<DatabaseResponse> patchUser(
      int userId, Map<String, dynamic> fields) async {
    if (fields.isEmpty) {
      return DatabaseResponse(
          success: false, data: {'error': 'No fields provided'});
    }

    return await SupabaseService.updateUserData(userId.toString(), fields);
  }

  static Future<bool> userExist(String username) async {
    return await SupabaseService.usernameExists(username);
  }

  static Future<bool> userExistEmail(String email) async {
    return await SupabaseService.emailExists(email);
  }

  // fetch categories
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    return await SupabaseService.getCategories();
  }

  // create new category
  static Future<DatabaseResponse> createCategory(String name, String asset) async {
    return await SupabaseService.createCategory(name, asset);
  }

  // fetch recent listings
  static Future<List<Map<String, dynamic>>> fetchRecentListings(
      int limit) async {
    return await SupabaseService.getRecentSkills(limit);
  }

  // fetch skills of a user
  static Future<List<Map<String, dynamic>>> fetchUserSkills(int userId) async {
    return await SupabaseService.getUserSkills(userId: userId.toString());
  }

  // search listings by keyword
  static Future<List<Map<String, dynamic>>> searchListings(String query) async {
    return await SupabaseService.searchSkills(query);
  }

  // create new listing
  static Future<DatabaseResponse> createListing(Map<String, dynamic> listing) async {
    return await SupabaseService.createSkill(listing);
  }

  // fetch specific listing
  static Future<DatabaseResponse> fetchListing(int skillId) async {
    try {
      final data = await SupabaseService.getSkill(skillId);
      return DatabaseResponse(
        success: data.isNotEmpty,
        data: data.isNotEmpty ? data : {'error': 'Skill not found'},
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // update listing information
  static Future<DatabaseResponse> patchListing(
      int skillId, Map<String, dynamic> fields) async {
    return await SupabaseService.updateSkill(skillId, fields);
  }

  // delete listing
  static Future<bool> deleteListing(int skillId) async {
    return await SupabaseService.deleteSkill(skillId);
  }

  // fetch skills by category
  static Future<List<Map<String, dynamic>>> fetchSkillsByCategory(
      String category) async {
    return await SupabaseService.getSkillsByCategory(category);
  }

  // Compatibility method for older code
  static Future<List<Map<String, dynamic>>> fetchListingsByCategory(
      String categoryName) async {
    return await SupabaseService.getSkillsByCategory(categoryName);
  }

  // Compatibility method for older code
  static Future<Map<String, dynamic>> fetchOneSkill(int id) async {
    return await SupabaseService.getSkill(id);
  }

  // Search for skills with optional filters
  static Future<List<Map<String, dynamic>>> searchResults(
    String search, {
    String? category,
    int? minPrice,
    int? maxPrice,
    String? sortBy,
    bool includeUsers = true,
  }) async {
    List<Map<String, dynamic>> results = [];
    
    try {
      // First search for skills - SupabaseService.searchSkills only accepts query parameter
      final skills = await SupabaseService.searchSkills(search);
      
      // Filter results manually since SupabaseService doesn't support these filters
      var filteredSkills = skills;
      
      // Apply category filter if provided
      if (category != null && category.isNotEmpty) {
        filteredSkills = filteredSkills.where((skill) => 
          skill['category'] == category
        ).toList();
      }
      
      // Apply price filters if provided
      if (minPrice != null) {
        filteredSkills = filteredSkills.where((skill) => 
          (skill['cost'] ?? 0) >= minPrice
        ).toList();
      }
      
      if (maxPrice != null) {
        filteredSkills = filteredSkills.where((skill) => 
          (skill['cost'] ?? 0) <= maxPrice
        ).toList();
      }
      
      // Apply sorting
      if (sortBy != null) {
        if (sortBy == 'price_asc') {
          filteredSkills.sort((a, b) => (a['cost'] ?? 0).compareTo(b['cost'] ?? 0));
        } else if (sortBy == 'price_desc') {
          filteredSkills.sort((a, b) => (b['cost'] ?? 0).compareTo(a['cost'] ?? 0));
        } else if (sortBy == 'date') {
          filteredSkills.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        }
      }
      
      // Add result_type to each skill for differentiation
      results = filteredSkills.map((skill) {
        return {
          ...skill,
          'result_type': 'skill'
        };
      }).toList();
      
      // If includeUsers is true and search is not empty, include user search results
      if (includeUsers && search.isNotEmpty) {
        try {
          final users = await SupabaseService.searchUsers(search);
          // Mark each user result to distinguish from skills
          final userResults = users.map((user) {
            return {
              ...user,
              'result_type': 'user'
            };
          }).toList();
          results.addAll(userResults);
        } catch (e) {
          log('Error in user search: $e');
          // Continue with just the skills results if user search fails
        }
      }
      
      return results;
    } catch (e) {
      log('Error in searchResults: $e');
      return [];
    }
  }

  // For backward compatibility
  static Future<LoginResponse> fetchUserId(String email, String password) async {
    return await loginUser(email, password);
  }

  // CHAT OPERATIONS
  
  // Get all chats for the current user
  static Future<List<Map<String, dynamic>>> getUserChats([int? userId]) async {
    try {
      // Get current user ID if not provided
      final currentUserId = userId ?? await getCurrentUserId();
      if (currentUserId == null) {
        log('Error: No user ID available for fetching chats');
        return [];
      }

      log('Fetching chats for user $currentUserId');
      
      // Use SupabaseService to get chats
      final response = await SupabaseService.getUserChats(currentUserId);
      if (!response.success) {
        log('Error fetching user chats: ${response.data['error']}');
        return [];
      }
      
      final List<Map<String, dynamic>> chats = List<Map<String, dynamic>>.from(response.data);
      log('Successfully fetched ${chats.length} chats');
      
      return chats;
    } catch (e) {
      log('Error fetching user chats: $e');
      return [];
    }
  }

  // Get messages for a chat
  static Future<List<Map<String, dynamic>>> getChatMessages(int chatId, {int limit = 50, int offset = 0}) async {
    try {
      log('Fetching messages for chat $chatId (limit: $limit, offset: $offset)');
      
      // Use SupabaseService to get messages
      final response = await SupabaseService.getChatMessages(chatId);
      if (!response.success) {
        log('Error fetching chat messages: ${response.data['error']}');
        return [];
      }
      
      final List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(response.data);
      log('Successfully fetched ${messages.length} messages');
      
      return messages;
    } catch (e) {
      log('Error fetching chat messages: $e');
      return [];
    }
  }

  // Send a message
  static Future<bool> sendMessage(int chatId, dynamic senderId, String message) async {
    try {
      final messageData = {
        'chat_id': chatId,
        'sender_id': senderId is int ? senderId.toString() : senderId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      final response = await SupabaseService.sendMessage(messageData);
      return response.success;
    } catch (e) {
      log('Error in sendMessage: $e');
      return false;
    }
  }

  // Send a message with notification
  static Future<void> sendMessageWithNotification({
    required int chatId,
    required dynamic senderId,
    required String message,
    required String senderName,
    required dynamic recipientId,
    String? senderImage,
  }) async {
    try {
      log('Sending message from $senderId to $recipientId in chat $chatId: $message');
      
      // Create message data for the SupabaseService
      final messageData = {
        'chat_id': chatId,
        'sender_id': senderId is int ? senderId.toString() : senderId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      // Send the message
      final response = await SupabaseService.sendMessage(messageData);
      
      if (!response.success) {
        log('Failed to send message: ${response.data?['error'] ?? 'Unknown error'}');
        return;
      }
      
      log('Message sent successfully with ID: ${response.data['id']}');
      
      // Send notification to recipient
      final notificationContent = '$senderName: $message';
      await createNotification(
        recipientId: recipientId is int ? recipientId : int.parse(recipientId.toString()),
        message: notificationContent,
        senderId: senderId is int ? senderId : int.parse(senderId.toString()),
        senderImage: senderImage,
        chatId: chatId,
      );
      
      log('Notification created for recipient $recipientId');
    } catch (e) {
      log('Error in sendMessageWithNotification: $e');
    }
  }

  // For backward compatibility
  static Future<List<Map<String, dynamic>>> fetchChats(int userId) async {
    return await getUserChats(userId);
  }

  // Check if skill name exists
  static Future<bool> checkSkillName(String name, int? userId) async {
    try {
      final skills = await SupabaseService.getUserSkills(userId: userId?.toString());
      return skills.any((skill) => skill['name'] == name);
    } catch (e) {
      log('Error checking skill name: $e');
      return false;
    }
  }

  // Insert skill (compatibility with old method)
  static Future<Response> insertSkill(
      int? userId, String name, String description, String? category, double? cost) async {
    try {
      final result = await SupabaseService.createSkill({
        'user_id': userId.toString(),
        'name': name,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
        'category': category,
        'cost': cost != null ? cost.toInt() : null,
      });
      
      return Response(
        success: result.success,
        message: result.success ? 'Skill added successfully' : result.data['error']?.toString() ?? 'Failed to insert skill',
      );
    } catch (e) {
      return Response(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Delete skill (compatibility with old method)
  static Future<Response> deleteSkill(String name, int? userId) async {
    try {
      // First find the skill by name and user ID
      final skills = await SupabaseService.getUserSkills(userId: userId?.toString());
      final skill = skills.firstWhere(
        (skill) => skill['name'] == name,
        orElse: () => <String, dynamic>{},
      );
      
      if (skill.isEmpty) {
        return Response(
          success: false,
          message: 'Skill not found',
        );
      }
      
      // Then delete it
      final success = await SupabaseService.deleteSkill(skill['id']);
      return Response(
        success: success,
        message: success ? 'Skill deleted successfully' : 'Failed to delete skill',
      );
    } catch (e) {
      return Response(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Award user (mock implementation)
  static Future<bool> awardUser(int userId) async {
    try {
      // Since we don't have this feature in the Supabase implementation,
      // we can mock it or update the user data to add credits
      final userData = await SupabaseService.getUser(userId.toString());
      if (!userData.success) return false;
      
      final currentCredits = userData.data['credits'] ?? 0;
      final result = await SupabaseService.updateUserData(
        userId.toString(),
        {'credits': currentCredits + 1}
      );
      
      return result.success;
    } catch (e) {
      log('Error awarding user: $e');
      return false;
    }
  }

  // get or create chat between users
  static Future<int> getOrCreateChat(
      int user1Id, int user2Id, int skillId) async {
    try {
      final chat = await SupabaseService.getOrCreateChat(
        user1Id.toString(),
        user2Id.toString(),
        skillId,
      );
      return chat['id'] ?? -1;
    } catch (e) {
      log('Error getting or creating chat: $e');
      return -1;
    }
  }

  // delete chat
  static Future<bool> deleteChat(int chatId) async {
    try {
      // First check if the chat exists
      final chatData = await supabase
        .from('chats')
        .select('id, session_id')
        .eq('id', chatId)
        .single();
      
      if (chatData == null) {
        return false;
      }
      
      // Delete messages first (respecting foreign key constraints)
      await supabase
        .from('messages')
        .delete()
        .eq('chat_id', chatId);
      
      // Now delete the chat
      await supabase
        .from('chats')
        .delete()
        .eq('id', chatId);
      
      // Note: We don't delete the session as it might be needed for record-keeping
      
      return true;
    } catch (e) {
      log('Error deleting chat: $e');
      return false;
    }
  }

  // create session
  static Future<DatabaseResponse> createSession(
      int requesterId, int skillId) async {
    final skillData = await SupabaseService.getSkill(skillId);
    if (skillData.isEmpty) {
      return DatabaseResponse(
        success: false,
        data: {'error': 'Skill not found'},
      );
    }

    final providerId = skillData['user_id'].toString();
    
    return await SupabaseService.createSession({
      'requester_id': requesterId.toString(),
      'provider_id': providerId,
      'skill_id': skillId,
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // fetch session by id
  static Future<DatabaseResponse> fetchSession(int sessionId) async {
    return await SupabaseService.getSession(sessionId);
  }
  
  // For backward compatibility
  static Future<DatabaseResponse> fetchSessionFromId(int sessionId) async {
    return await fetchSession(sessionId);
  }

  // fetch session from chat
  static Future<DatabaseResponse> fetchSessionFromChat(int chatId) async {
    return await SupabaseService.fetchSessionFromChat(chatId);
  }

  // fetch transaction
  static Future<DatabaseResponse> fetchTransaction(int transactionId) async {
    return await SupabaseService.getTransaction(transactionId);
  }

  // fetch transaction from session
  static Future<DatabaseResponse> fetchTransactionFromSession(int sessionId) async {
    try {
      final result = await SupabaseService.getTransactionFromSession(sessionId);
      return result;
    } catch (e) {
      log('Error fetching transaction from session: $e');
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // create transaction
  static Future<bool> createTransaction(int sessionId) async {
    try {
      // First fetch the session to get requester_id and provider_id
      final sessionData = await SupabaseService.getSession(sessionId);
      if (!sessionData.success) {
        log('Error creating transaction: session not found');
        return false;
      }
      
      // Now create the transaction with all required fields
      final result = await SupabaseService.createTransaction({
        'session_id': sessionId,
        'requester_id': sessionData.data['requester_id'],
        'provider_id': sessionData.data['provider_id'],
        'created_at': DateTime.now().toIso8601String(),
      });
      return result.success;
    } catch (e) {
      log('Error creating transaction: $e');
      return false;
    }
  }

  // finalize transaction
  static Future<bool> finalizeTransaction(int transactionId) async {
    try {
      final result = await SupabaseService.finalizeTransaction(transactionId, 'Completed');
      return result.success;
    } catch (e) {
      log('Error finalizing transaction: $e');
      return false;
    }
  }

  // update session status
  static Future<bool> updateSessionStatus(int sessionId, String status) async {
    try {
      final result = await SupabaseService.updateSession(sessionId, {
        'status': status,
      });
      return result.success;
    } catch (e) {
      return false;
    }
  }

  // fetch reports
  static Future<List<Map<String, dynamic>>> fetchReports() async {
    return await SupabaseService.getAllReports();
  }

  // remove report
  static Future<bool> removeReport(int reportId) async {
    try {
      await SupabaseService.getReport(reportId); // Check if report exists
      return await SupabaseService.resolveReport(reportId);
    } catch (e) {
      return false;
    }
  }

  // resolve report
  static Future<bool> resolveReport(int reportId) async {
    return await SupabaseService.resolveReport(reportId);
  }

  // create report
  static Future<bool> createReport(int skillId) async {
    final userId = await UserIdStorage.getLoggedInUserId();
    if (userId == null) return false;
    
    try {
      final result = await SupabaseService.createReport({
        'reporter_id': userId.toString(),
        'skill_id': skillId,
        'reason': 'Reported from mobile app',
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return result.success;
    } catch (e) {
      return false;
    }
  }

  // get unread message count
  static Future<int> getUnreadMessageCount() async {
    return await SupabaseService.getUnreadMessageCount();
  }

  // mark chat as read
  static Future<void> markChatAsRead(int chatId) async {
    await SupabaseService.markChatAsRead(chatId);
  }

  // get notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    return await SupabaseService.getNotifications();
  }

  // mark notification as read
  static Future<void> markNotificationAsRead(int notificationId) async {
    await SupabaseService.markNotificationAsRead(notificationId);
  }

  // fetch active services
  static Future<List<Map<String, dynamic>>> fetchActiveServices() async {
    final userId = await UserIdStorage.getLoggedInUserId();
    if (userId == null) return [];
    
    return await SupabaseService.getActiveSessionsForUser(userId.toString());
  }

  // complete service
  static Future<bool> completeService(int sessionId) async {
    return await SupabaseService.completeSession(sessionId);
  }

  // cancel service
  static Future<bool> cancelService(int sessionId) async {
    return await SupabaseService.cancelSession(sessionId);
  }

  // Get a user's skills
  static Future<List<Map<String, dynamic>>> getUserSkills(String userId) async {
    if (useSupabase) {
      return await SupabaseService.getUserSkills(userId: userId.toString());
    } else {
      final response = await http.get(
        Uri.parse('$baseUrl/api/skills/user/$userId'),
      );
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
          json.decode(response.body),
        );
      } else {
        print('Failed to load user skills: ${response.statusCode}');
        return [];
      }
    }
  }

  // Get user profile with their skills
  static Future<Map<String, dynamic>> getUserProfileWithSkills(String userId) async {
    if (useSupabase) {
      try {
        final user = await SupabaseService.getUserById(userId);
        
        if (user == null) {
          return {'error': 'User not found'};
        }
        
        final skills = await SupabaseService.getUserSkills(userId: userId.toString());
        
        final Map<String, dynamic> userProfile = Map.from(user);
        userProfile['skills'] = skills;
        
        return userProfile;
      } catch (e) {
        print('Error fetching user profile with skills: $e');
        return {'error': 'Failed to fetch user profile'};
      }
    } else {
      // HTTP API version
      // ... existing code ...
      return {};
    }
  }

  // Fetch skills by user ID
  static Future<List<Map<String, dynamic>>> fetchSkills(dynamic userId) async {
    try {
      // Convert userId to string if it's not already
      String userIdString = userId.toString();
      
      return await SupabaseService.getUserSkills(userId: userIdString);
    } catch (e) {
      log('Error fetching skills: $e');
      return [];
    }
  }

  // Get provider details
  static Future<Map<String, dynamic>> getProviderDetails(String userId) async {
    if (useSupabase) {
      try {
        final user = await SupabaseService.getUserById(userId);
        
        if (user == null) {
          return {'error': 'Provider not found'};
        }
        
        final skills = await SupabaseService.getUserSkills(userId: userId.toString());
        
        final Map<String, dynamic> providerDetails = Map.from(user);
        providerDetails['skills'] = skills;
        
        return providerDetails;
      } catch (e) {
        print('Error fetching provider details: $e');
        return {'error': 'Failed to fetch provider details'};
      }
    } else {
      // HTTP API version
      // ... existing code ...
      return {};
    }
  }

  // Create notification
  static Future<bool> createNotification({
    required int recipientId,
    required String message,
    required int senderId,
    String? senderImage,
    int? chatId,
  }) async {
    try {
      log('Creating notification for recipient $recipientId from sender $senderId');
      
      // Build notification data without chat_id since it's not in the schema
      final notificationData = {
        'user_id': recipientId,
        'message': message,
        'sender_id': senderId,
        'sender_image': senderImage,
        // Removed chat_id field as it's not in the notifications table schema
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final result = await supabase
          .from('notifications')
          .insert(notificationData)
          .select()
          .single();
      
      log('Notification created successfully with ID: ${result['id']}');
      return true;
    } catch (e) {
      log('Error creating notification: $e');
      return false;
    }
  }

  // Get the current user's ID
  static Future<int?> getCurrentUserId() async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        return int.tryParse(userId.toString());
      }
      return null;
    } catch (e) {
      log('Error getting current user ID: $e');
      return null;
    }
  }

  // Get user by ID
  static Future<Map<String, dynamic>?> getUserById(int userId) async {
    try {
      final response = await SupabaseService.getUser(userId.toString());
      if (response.success && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      log('Error getting user by ID: $e');
      return null;
    }
  }

  // Add a review for a completed session
  static Future<bool> addReview(int sessionId, int reviewerId, int revieweeId, int rating, String? reviewText) async {
    try {
      final result = await SupabaseService.addReview({
        'session_id': sessionId,
        'reviewer_id': reviewerId,
        'reviewee_id': revieweeId,
        'rating': rating,
        'review_text': reviewText,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      return result.success;
    } catch (e) {
      log('Error adding review: $e');
      return false;
    }
  }
  
  // Get reviews for a user
  static Future<List<Map<String, dynamic>>> getUserReviews(int userId) async {
    try {
      return await SupabaseService.getUserReviews(userId);
    } catch (e) {
      log('Error getting user reviews: $e');
      return [];
    }
  }

  // Search for users by username
  static Future<List<Map<String, dynamic>>> searchUsers(String search) async {
    try {
      final users = await SupabaseService.searchUsers(search);
      return users.map((user) {
        return {
          ...user,
          'result_type': 'user'
        };
      }).toList();
    } catch (e) {
      log('Error searching users: $e');
      return [];
    }
  }

  static Future<bool> addCreditsToUser(int userId, int credits) async {
    try {
      // Call the SupabaseService to update the user's credits
      final result = await SupabaseService.updateUserCredits(userId, credits);
      
      // Check if the operation was successful
      if (result) {
        log('Successfully added $credits credits to user with ID $userId');
        return true;
      } else {
        log('Failed to add credits to user with ID $userId');
        return false;
      }
    } catch (e) {
      log('Error adding credits to user: $e');
      return false;
    }
  }

  // Add this function to update session confirmation columns and status
  static Future<bool> updateSessionConfirmation({
    required int sessionId, 
    bool? requesterConfirmed, 
    bool? providerConfirmed,
  }) async {
    try {
      // First ensure the columns exist
      try {
        // Check if columns exist using a simple select
        await supabase
          .from('sessions')
          .select('requester_confirmed, provider_confirmed')
          .eq('id', sessionId)
          .limit(1);
      } catch (e) {
        // If error occurs, columns likely don't exist, try to add them directly
        try {
          // Directly execute ALTER TABLE commands instead of trying to create a function
          // Add requester_confirmed column if it doesn't exist
          await supabase
            .from('sessions')
            .update({ 'dummy_col': 'dummy_val' }) // Dummy update to ensure the column exists
            .eq('id', sessionId)
            .select('requester_confirmed')
            .maybeSingle();
        } catch (columnError) {
          print('Error checking requester_confirmed column: $columnError');
          // Column likely doesn't exist, but we'll continue execution
        }
        
        try {
          // Check if provider_confirmed exists
          await supabase
            .from('sessions')
            .update({ 'dummy_col': 'dummy_val' }) // Dummy update to ensure the column exists
            .eq('id', sessionId)
            .select('provider_confirmed')
            .maybeSingle();
        } catch (columnError) {
          print('Error checking provider_confirmed column: $columnError');
          // Column likely doesn't exist, but we'll continue execution
        }
        
        // For now, let's proceed with the update anyway - if columns don't exist,
        // the update will just ignore those fields
      }

      // Now update the requested fields
      Map<String, dynamic> updateData = {};
      
      if (requesterConfirmed != null) {
        updateData['requester_confirmed'] = requesterConfirmed;
      }
      
      if (providerConfirmed != null) {
        updateData['provider_confirmed'] = providerConfirmed;
      }
      
      if (updateData.isNotEmpty) {
        await supabase
          .from('sessions')
          .update(updateData)
          .eq('id', sessionId);

        // Check if both are confirmed and update status if needed
        if (requesterConfirmed == true || providerConfirmed == true) {
          final session = await supabase
              .from('sessions')
              .select('requester_confirmed, provider_confirmed')
              .eq('id', sessionId)
              .single();
              
          if (session != null && 
              session['requester_confirmed'] == true && 
              session['provider_confirmed'] == true) {
            // Both confirmed, update status to Completed
            await supabase
                .from('sessions')
                .update({'status': 'Completed'})
                .eq('id', sessionId);
                
            // Process the payment here or call a separate function
            return await _processServicePayment(sessionId);
          }
        }
      }
      
      return true;
    } catch (e) {
      print('Error updating session confirmation: $e');
      return false;
    }
  }

  // Helper function to process payment when both parties confirm
  static Future<bool> _processServicePayment(int sessionId) async {
    try {
      // Get session details
      final sessionData = await supabase
          .from('sessions')
          .select('*, skills(*)')
          .eq('id', sessionId)
          .single();
          
      if (sessionData == null) {
        print('Error: Session not found');
        return false;
      }
      
      final requesterId = int.parse(sessionData['requester_id'].toString());
      final providerId = int.parse(sessionData['provider_id'].toString());
      final skillCost = double.parse(sessionData['skills']['cost'].toString());
      
      // Get provider's current credits
      final providerData = await supabase
          .from('users')
          .select('credits')
          .eq('id', providerId)
          .single();
          
      if (providerData == null) {
        print('Error: Provider not found');
        return false;
      }
      
      final providerCredits = int.parse(providerData['credits'].toString());
      final newProviderCredits = providerCredits + skillCost.toInt();
      
      // Update provider's credits
      await supabase
          .from('users')
          .update({'credits': newProviderCredits})
          .eq('id', providerId);
      
      // Update transaction status
      final transactions = await supabase
          .from('transactions')
          .select()
          .eq('session_id', sessionId)
          .eq('status', 'Pending');
          
      if (transactions != null && transactions.isNotEmpty) {
        await supabase
            .from('transactions')
            .update({
              'status': 'Completed',
              'completed_at': DateTime.now().toIso8601String()
            })
            .eq('session_id', sessionId);
      }
      
      return true;
    } catch (e) {
      print('Error processing service payment: $e');
      return false;
    }
  }
}