import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'userIdStorage.dart';
import 'models.dart'; // Import shared models

// Access the Supabase client from main.dart
final supabase = Supabase.instance.client;

class SupabaseService {
  // Helper method for better logging
  static void _logOperation(String operation, String details, {bool isError = false}) {
    final timestamp = DateTime.now().toString().split('.').first;
    final prefix = isError ? '❌ ERROR' : '✅ INFO';
    log('[$timestamp] $prefix - $operation: $details');
  }
  
  // UTILITY FUNCTIONS
  
  // Convert user ID between string/int as needed
  static dynamic _convertUserId(dynamic userId) {
    if (userId is int) {
      return userId.toString();
    } else if (userId is String) {
      // Try to parse as int if possible (for backward compatibility)
      try {
        return int.parse(userId);
      } catch (_) {
        return userId; // Keep as string if it's not a valid int
      }
    }
    return userId;
  }
  
  // Check if the current user has access to the resource
  static Future<bool> _checkAccess(String table, String id, {String? action}) async {
    try {
      // This is a simple implementation - real RLS would be in Supabase policies
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return false;
      
      if (table == 'users' && id == currentUser.id) {
        return true; // Users can access their own data
      }
      
      // For other resources, check if the user owns them
      final resource = await supabase.from(table).select().eq('id', id).maybeSingle();
      if (resource != null && resource['user_id'] == currentUser.id) {
        return true;
      }
      
      return false;
    } catch (e) {
      log('Error checking access: $e');
      return false;
    }
  }
  
  // AUTH OPERATIONS
  
  // Sign up with email and password
  static Future<LoginResponse> registerUser(
      String username, String email, String password) async {
    
      _logOperation('Registration', 'Starting user registration for: $email');
      
      try {
        // Check if username or email already exists
        final userExists = await usernameExists(username);
        if (userExists) {
          _logOperation('Registration', 'Username already exists: $username', isError: true);
          return LoginResponse(
            success: false,
            message: 'Username already exists',
          );
        }
        
        final isEmailTaken = await emailExists(email);
        if (isEmailTaken) {
          _logOperation('Registration', 'Email already exists: $email', isError: true);
          return LoginResponse(
            success: false,
            message: 'Email already exists',
          );
        }
        
        // First create the auth user
        _logOperation('Registration', 'Creating auth user with email and password');
        final authResponse = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': username,
          },
        );

        if (authResponse.user != null) {
          _logOperation('Registration', 'Auth user created successfully with ID: ${authResponse.user!.id}');
          final authId = authResponse.user!.id;
          
          // Create a profile entry in the users table
          try {
            _logOperation('Registration', 'Creating user profile in database');
            final result = await supabase.from('users').insert({
              'username': username,
              'email': email,
              'password': password, // Required per schema
              'credits': 0, // Required per schema default
              'auth_id': authId, // Store the auth ID for reference
            }).select();
            
            _logOperation('Registration', 'User profile created successfully: $result');
            
            // Now let's get the ID that was assigned
            if (result.isNotEmpty) {
              final userId = result[0]['id'];
              _logOperation('Registration', 'Database assigned user ID: $userId');
              
              // Store the user ID for future reference
              try {
                await UserIdStorage.saveLoggedInUserId(userId);
                _logOperation('Registration', 'User ID saved in local storage: $userId');
                
                // Map the Auth ID to the database ID in Supabase Auth metadata
                await supabase.auth.updateUser(UserAttributes(
                  data: {
                    'db_user_id': userId,
                  }
                ));
                _logOperation('Registration', 'Updated auth metadata with db_user_id: $userId');
                
                return LoginResponse(
                  success: true,
                  message: 'User registered successfully',
                  userId: userId,
                );
              } catch (storageError) {
                _logOperation('Registration', 'Error saving user ID: $storageError', isError: true);
                return LoginResponse(
                  success: true,
                  message: 'User created but ID storage failed',
                  userId: userId,
                );
              }
            } else {
              _logOperation('Registration', 'No result returned from user insertion', isError: true);
              return LoginResponse(
                success: false,
                message: 'User creation failed - no ID returned',
              );
            }
          } catch (profileError) {
            _logOperation('Registration', 'Error creating user profile: $profileError', isError: true);
            
            // Try to delete the auth user since profile creation failed
            try {
              await supabase.auth.admin.deleteUser(authId);
              _logOperation('Registration', 'Cleaned up auth user after profile creation error');
            } catch (e) {
              _logOperation('Registration', 'Failed to clean up auth user after profile creation error: $e', isError: true);
            }
            
            return LoginResponse(
              success: false,
              message: 'Failed to create user profile: ${profileError.toString()}',
            );
          }
        } else {
          _logOperation('Registration', 'Auth response had no user', isError: true);
          return LoginResponse(
            success: false,
            message: 'Failed to register user',
          );
        }
      } on AuthException catch (e) {
        _logOperation('Registration', 'Auth exception: ${e.message}', isError: true);
        return LoginResponse(
          success: false,
          message: e.message,
        );
      } catch (e) {
        _logOperation('Registration', 'Unexpected error: $e', isError: true);
        return LoginResponse(
          success: false,
          message: e.toString(),
        );
      }
    }

  // Sign in with email and password
  static Future<LoginResponse> signInWithEmail(
      String email, String password) async {
    try {
      _logOperation('Login', 'Attempting sign in for email: $email');
      
      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        _logOperation('Login', 'Authentication successful for auth user: ${authResponse.user!.id}');
        
        // Get the database user record
        try {
          // First check if we have db_user_id in auth metadata
          final dbUserId = authResponse.user!.userMetadata?['db_user_id'];
          
          if (dbUserId != null) {
            _logOperation('Login', 'Found db_user_id in auth metadata: $dbUserId');
            
            // Store this ID for future use
            await UserIdStorage.saveLoggedInUserId(dbUserId);
            
            return LoginResponse(
              success: true,
              message: 'Login successful',
              userId: dbUserId,
            );
          }
          
          // If not found in metadata, look up by email
          _logOperation('Login', 'No db_user_id in metadata, looking up user by email: $email');
          final userData = await supabase
              .from('users')
              .select()
              .eq('email', email)
              .single();
          
          final userId = userData['id'];
          _logOperation('Login', 'Found database user ID: $userId');
          
          // Store the ID for future use
          await UserIdStorage.saveLoggedInUserId(userId);
          
          // Update auth metadata for future logins
          await supabase.auth.updateUser(UserAttributes(
            data: {
              'db_user_id': userId,
            }
          ));
          _logOperation('Login', 'Updated auth metadata with db_user_id: $userId');
          
          return LoginResponse(
            success: true,
            message: 'Login successful',
            userId: userId,
          );
                } catch (e) {
          _logOperation('Login', 'Error retrieving user record: $e', isError: true);
          return LoginResponse(
            success: false,
            message: 'Failed to retrieve user data',
          );
        }
      } else {
        _logOperation('Login', 'Auth response had no user during login', isError: true);
        return LoginResponse(
          success: false,
          message: 'Failed to login',
        );
      }
    } on AuthException catch (e) {
      _logOperation('Login', 'Auth exception: ${e.message}', isError: true);
      return LoginResponse(
        success: false,
        message: e.message,
      );
    } catch (e) {
      _logOperation('Login', 'Unexpected error: $e', isError: true);
      return LoginResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  // Direct authentication from users table
  static Future<LoginResponse> authenticateFromUsersTable(String email, String password) async {
    try {
      _logOperation('DirectLogin', 'Attempting direct login from users table for email: $email');
      
      // Call the PostgreSQL function we created
      final response = await supabase.rpc('authenticate_user', params: {
        'user_email': email,
        'user_password': password
      });
      
      _logOperation('DirectLogin', 'Authentication response: $response');
      
      // Check if authentication was successful
      if (response != null && response['success'] == true) {
        final userId = response['user_id'];
        _logOperation('DirectLogin', 'Authentication successful for user ID: $userId');
        
        // Store the userId for future use
        await UserIdStorage.saveLoggedInUserId(userId);
        
        return LoginResponse(
          success: true,
          message: 'Login successful',
          userId: userId,
        );
      } else {
        final errorMessage = response?['message'] ?? 'Invalid email or password';
        _logOperation('DirectLogin', 'Authentication failed: $errorMessage', isError: true);
        
        return LoginResponse(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e) {
      _logOperation('DirectLogin', 'Error during direct authentication: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Authentication error: ${e.toString()}',
      );
    }
  }

  // Direct SQL authentication 
  static Future<LoginResponse> authenticateViaDirectSQL(String email, String password) async {
    try {
      _logOperation('DirectSQL', 'Attempting direct SQL authentication for: $email');
      
      // Direct SQL query instead of RPC function call
      final response = await supabase
          .from('users')
          .select('id, username, email')
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();
      
      _logOperation('DirectSQL', 'Authentication response: $response');
      
      if (response != null) {
        final userId = response['id'];
        _logOperation('DirectSQL', 'Authentication successful for user ID: $userId');
        
        // Store this ID for future use
        await UserIdStorage.saveLoggedInUserId(userId);
        
        return LoginResponse(
          success: true,
          message: 'Login successful',
          userId: userId,
        );
      } else {
        _logOperation('DirectSQL', 'Authentication failed: Invalid credentials', isError: true);
        
        return LoginResponse(
          success: false,
          message: 'Invalid email or password',
        );
      }
    } catch (e) {
      _logOperation('DirectSQL', 'Error during direct SQL authentication: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Authentication error: ${e.toString()}',
      );
    }
  }

  // For backward compatibility with original DatabaseHelper
  static Future<LoginResponse> fetchUserId(String email, String password) async {
    // Try direct SQL authentication first
    try {
      return await authenticateViaDirectSQL(email, password);
    } catch (directAuthError) {
      _logOperation('Login', 'Direct SQL authentication failed, trying RPC: $directAuthError', isError: true);
      
      // Try RPC function as second option
      try {
        return await authenticateFromUsersTable(email, password);
      } catch (rpcError) {
        _logOperation('Login', 'RPC authentication failed, falling back to Supabase Auth: $rpcError', isError: true);
        
        // Fall back to Supabase Auth if direct authentication fails
        return await signInWithEmail(email, password);
      }
    }
  }

  // Sign in with Apple
  static Future<LoginResponse> signInWithApple() async {
    try {
      log('Starting Apple sign-in process');
      // Generate a random nonce for security
      final rawNonce = supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      
      // Request credential from Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException(
          'Could not find ID Token from Apple Sign In.',
        );
      }
      
      // Sign in with Supabase using the Apple token
      final AuthResponse res = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      
      if (res.user != null) {
        log('Successfully signed in with Apple, auth user ID: ${res.user!.id}');
        
        // First check if we have db_user_id in auth metadata
        final dbUserId = res.user!.userMetadata?['db_user_id'];
        
        if (dbUserId != null) {
          log('Found db_user_id in auth metadata: $dbUserId');
          
          // Store this ID for future use
          await UserIdStorage.saveLoggedInUserId(dbUserId);
          
          return LoginResponse(
            success: true,
            message: 'Login with Apple successful',
            userId: dbUserId,
          );
        }
        
        // Get user email (from credential or from auth user)
        final email = credential.email ?? res.user!.email;
        
        if (email == null) {
          log('No email found in Apple credentials or auth user');
          return LoginResponse(
            success: false,
            message: 'Unable to retrieve email from Apple sign-in',
          );
        }
        
        // Check if user with this email already exists
        try {
          final userData = await supabase
              .from('users')
              .select()
              .eq('email', email)
              .maybeSingle();
          
          // If user exists, link the auth account to it
          if (userData != null) {
            final userId = userData['id'];
            log('Found existing user with this email: $userId');
            
            // Store the ID for future use
            await UserIdStorage.saveLoggedInUserId(userId);
            
            // Update auth metadata for future logins
            await supabase.auth.updateUser(UserAttributes(
              data: {
                'db_user_id': userId,
              }
            ));
            
            return LoginResponse(
              success: true,
              message: 'Login with Apple successful',
              userId: userId,
            );
          }
          
          // User doesn't exist, create a new one
          // Get name from Apple credential if available
          String? firstName = credential.givenName;
          String? lastName = credential.familyName;
          String username = "User"; // Default name if none provided
          
          if (firstName != null || lastName != null) {
            username = [
              if (firstName != null) firstName,
              if (lastName != null) lastName,
            ].join(' ');
          }
          
          log('Creating new user profile for Apple user');
          final result = await supabase.from('users').insert({
            // Don't specify 'id' field - let the database auto-generate it
            'username': username,
            'email': email,
            'password': 'apple_oauth_${DateTime.now().millisecondsSinceEpoch}', // Required by schema
            'credits': 0, // Required per schema
            // created_at has a default value in the schema
          }).select();
          
          if (result.isNotEmpty) {
            final userId = result[0]['id'];
            log('Created new user with ID: $userId');
            
            // Store the ID for future use
            await UserIdStorage.saveLoggedInUserId(userId);
            
            // Update auth metadata for future logins
            await supabase.auth.updateUser(UserAttributes(
              data: {
                'db_user_id': userId,
              }
            ));
            
            return LoginResponse(
              success: true,
              message: 'Login with Apple successful',
              userId: userId,
            );
          } else {
            log('No result returned from user insertion');
            return LoginResponse(
              success: false,
              message: 'User creation failed - no ID returned',
            );
          }
        } catch (e) {
          log('Error handling Apple sign-in user: $e');
          return LoginResponse(
            success: false,
            message: 'Error during Apple sign-in: $e',
          );
        }
      } else {
        log('Apple sign-in auth response had no user');
        return LoginResponse(
          success: false,
          message: 'Failed to login with Apple',
        );
      }
    } catch (e) {
      log('Apple sign-in error: $e');
      return LoginResponse(
        success: false,
        message: 'Error signing in with Apple: $e',
      );
    }
  }

  // Sign out
  static Future<bool> signOut() async {
    try {
      await supabase.auth.signOut();
      await UserIdStorage.clearLoggedInUserId();
      return true;
    } catch (e) {
      log('Error signing out: $e');
      return false;
    }
  }

  // USER OPERATIONS
  
  // Get user by ID
  static Future<DatabaseResponse> getUser(String userId) async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Search users by username or email
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final result = await supabase
          .from('users')
          .select()
          .or('username.ilike.%$query%,email.ilike.%$query%')
          .limit(20);
          
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      log('Error searching users: $e');
      return [];
    }
  }

  // Check if username exists
  static Future<bool> usernameExists(String username) async {
    try {
      final data = await supabase
          .from('users')
          .select('id')
          .eq('username', username);
          
      return data.isNotEmpty;
    } catch (e) {
      log('Error checking username: $e');
      return false;
    }
  }

  // Check if email exists
  static Future<bool> emailExists(String email) async {
    try {
      final data = await supabase
          .from('users')
          .select('id')
          .eq('email', email);
          
      return data.isNotEmpty;
    } catch (e) {
      log('Error checking email: $e');
      return false;
    }
  }

  // Update user data
  static Future<DatabaseResponse> updateUserData(
      String userId, Map<String, dynamic> updates) async {
    try {
      await supabase
          .from('users')
          .update(updates)
          .eq('id', userId);
          
      // Fetch the updated user data
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // Get user by email
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      log('Looking up user by email: $email');
      final response = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (response != null) {
        log('Found user with email: $email, user ID: ${response['id']}');
        return response;
      } else {
        log('No user found with email: $email');
        return null;
      }
    } catch (e) {
      log('Error retrieving user by email: $e');
      return null;
    }
  }

  // SKILLS OPERATIONS
  
  // Get skill by ID
  static Future<Map<String, dynamic>> getSkill(int skillId) async {
    try {
      final data = await supabase
          .from('skills')
          .select()
          .eq('id', skillId)
          .single();
          
      return data;
    } catch (e) {
      log('Error getting skill: $e');
      return {};
    }
  }
  
  // Get recent skills
  static Future<List<Map<String, dynamic>>> getRecentSkills(int limit) async {
    try {
      final data = await supabase
          .from('skills')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error getting recent skills: $e');
      return [];
    }
  }
  
  // Get skills by category
  static Future<List<Map<String, dynamic>>> getSkillsByCategory(String categoryName) async {
    try {
      final data = await supabase
          .from('skills')
          .select('*, categories(*)')
          .eq('categories.name', categoryName);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error getting skills by category: $e');
      return [];
    }
  }
  
  // Get skills for a user
  static Future<List<Map<String, dynamic>>> getUserSkills({String? userId}) async {
    try {
      // If no userId provided, get current user ID
      final currentUserId = userId ?? await UserIdStorage.getLoggedInUserId();
      
      if (currentUserId == null) {
        _logOperation('Skills', 'No user ID available for getUserSkills', isError: true);
        return [];
      }
      
      _logOperation('Skills', 'Fetching skills for user ID: $currentUserId');
      
      final response = await supabase
          .from('skills')
          .select('*, categories(name)')
          .eq('user_id', currentUserId);
      
      _logOperation('Skills', 'Found ${response.length} skills for user $currentUserId');
      return List<Map<String, dynamic>>.from(response);
        } catch (e) {
      _logOperation('Skills', 'Error fetching user skills: $e', isError: true);
      return [];
    }
  }
  
  // Create skill
  static Future<DatabaseResponse> createSkill(Map<String, dynamic> skillData) async {
    try {
      _logOperation('Skills', 'Creating new skill with data: $skillData');
      
      // Validate required fields
      if (!skillData.containsKey('user_id') || 
          !skillData.containsKey('name') || 
          !skillData.containsKey('description') ||
          !skillData.containsKey('category') ||
          !skillData.containsKey('cost')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (user_id, name, description, category, cost)'},
        );
      }
      
      // Ensure user_id is an integer
      if (skillData['user_id'] is String) {
        try {
          skillData['user_id'] = int.parse(skillData['user_id']);
        } catch (e) {
          _logOperation('Skills', 'Failed to convert user_id to integer: ${skillData['user_id']}', isError: true);
        }
      }
      
      // Verify category exists
      try {
        final categoryCheck = await supabase
            .from('categories')
            .select('name')
            .eq('name', skillData['category'])
            .maybeSingle();
            
        if (categoryCheck == null) {
          _logOperation('Skills', 'Category does not exist: ${skillData['category']}', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Category does not exist: ${skillData['category']}'},
          );
        }
      } catch (e) {
        _logOperation('Skills', 'Error checking category: $e', isError: true);
      }
      
      final result = await supabase
          .from('skills')
          .insert(skillData)
          .select()
          .single();
      
      _logOperation('Skills', 'Skill created successfully with ID: ${result['id']}');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Skills', 'Error creating skill: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Update skill
  static Future<DatabaseResponse> updateSkill(int skillId, Map<String, dynamic> updates) async {
    try {
      await supabase
          .from('skills')
          .update(updates)
          .eq('id', skillId);
          
      final data = await supabase
          .from('skills')
          .select()
          .eq('id', skillId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Delete skill
  static Future<bool> deleteSkill(int skillId) async {
    try {
      await supabase
          .from('skills')
          .delete()
          .eq('id', skillId);
          
      return true;
    } catch (e) {
      log('Error deleting skill: $e');
      return false;
    }
  }
  
  // Search skills
  static Future<List<Map<String, dynamic>>> searchSkills(String query) async {
    try {
      final data = await supabase
          .from('skills')
          .select()
          .textSearch('name', query);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error searching skills: $e');
      return [];
    }
  }

  // CATEGORIES OPERATIONS
  
  // Get all categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final data = await supabase
          .from('categories')
          .select()
          .order('name');
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error getting categories: $e');
      return [];
    }
  }
  
  // Create a new category
  static Future<DatabaseResponse> createCategory(String name, String asset) async {
    try {
      _logOperation('Categories', 'Creating new category: $name with asset: $asset');
      
      // Check if the category already exists
      final existingCategories = await supabase
          .from('categories')
          .select()
          .eq('name', name);
          
      if (existingCategories.isNotEmpty) {
        _logOperation('Categories', 'Category already exists: $name', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Category already exists', 'name': name}
        );
      }
      
      // Create the new category
      final result = await supabase
          .from('categories')
          .insert({
            'name': name,
            'asset': asset,
          })
          .select();
          
      _logOperation('Categories', 'Category created successfully: $result');
      
      return DatabaseResponse(
        success: true,
        data: result.isNotEmpty ? result[0] : {'name': name, 'asset': asset}
      );
    } catch (e) {
      _logOperation('Categories', 'Error creating category: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // CHAT OPERATIONS
  
  // Get user chats
  static Future<DatabaseResponse> getUserChats(dynamic userId) async {
    try {
      _logOperation('Chats', 'Getting chats for user: $userId');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Chats', 'Failed to convert userId to integer: $userId', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Invalid userId format'},
          );
        }
      } else {
        parsedUserId = userId;
      }
      
      final data = await supabase
          .from('chats')
          .select('''
            id, 
            user1_id, 
            user2_id, 
            last_message, 
            last_updated,
            session_id,
            user1:user1_id (id, username),
            user2:user2_id (id, username),
            sessions:session_id (id, status, skill_id)
          ''')
          .or('user1_id.eq.$parsedUserId,user2_id.eq.$parsedUserId')
          .order('last_updated', ascending: false);
      
      _logOperation('Chats', 'Successfully retrieved ${data.length} chats for user: $parsedUserId');
      
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      _logOperation('Chats', 'Error getting user chats: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Send a message
  static Future<DatabaseResponse> sendMessage(Map<String, dynamic> messageData) async {
    try {
      _logOperation('Messages', 'Sending message: ${messageData.toString()}');
      
      // Convert sender_id to string if it's an integer
      if (messageData['sender_id'] is int) {
        messageData['sender_id'] = messageData['sender_id'].toString();
      }
      
      final result = await supabase
          .from('messages')
          .insert(messageData)
          .select()
          .single();
      
      _logOperation('Messages', 'Message sent successfully with ID: ${result['id']}');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Messages', 'Error sending message: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get chat messages
  static Future<DatabaseResponse> getChatMessages(dynamic chatId) async {
    try {
      _logOperation('Messages', 'Getting messages for chat: $chatId');
      
      // Ensure chatId is an integer
      int parsedChatId;
      if (chatId is String) {
        try {
          parsedChatId = int.parse(chatId);
        } catch (e) {
          _logOperation('Messages', 'Failed to convert chatId to integer: $chatId', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Invalid chatId format'},
          );
        }
      } else {
        parsedChatId = chatId;
      }
      
      final data = await supabase
          .from('messages')
          .select('''
            id, 
            chat_id, 
            sender_id, 
            message, 
            timestamp, 
            read,
            sender:sender_id (id, username)
          ''')
          .eq('chat_id', parsedChatId)
          .order('timestamp', ascending: true);
      
      _logOperation('Messages', 'Successfully retrieved ${data.length} messages for chat: $parsedChatId');
      
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      _logOperation('Messages', 'Error getting chat messages: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get or create chat
  static Future<Map<String, dynamic>> getOrCreateChat(String userId1, String userId2, int sessionId) async {
    try {
      _logOperation('Chats', 'Getting or creating chat for users $userId1, $userId2 with session $sessionId');
      
      // Check if chat exists between these users
      final existingChats = await supabase
          .from('chats')
          .select()
          .or('and(user1_id.eq.$userId1,user2_id.eq.$userId2),and(user1_id.eq.$userId2,user2_id.eq.$userId1)')
          .limit(1);
          
      if (existingChats.isNotEmpty) {
        final existingChat = existingChats[0];
        
        // If the chat exists but doesn't have a session_id, update it
        if (existingChat['session_id'] == null) {
          _logOperation('Chats', 'Updating existing chat with session ID: $sessionId');
          
          final updatedChat = await supabase
              .from('chats')
              .update({
                'session_id': sessionId,
                'last_updated': DateTime.now().toIso8601String(),
              })
              .eq('id', existingChat['id'])
              .select()
              .single();
              
          return updatedChat;
        }
        
        return existingChat;
      }
      
      // Create new chat
      _logOperation('Chats', 'Creating new chat with session ID: $sessionId');
      
      final newChat = await supabase
          .from('chats')
          .insert({
            'user1_id': userId1,
            'user2_id': userId2,
            'session_id': sessionId,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
          
      _logOperation('Chats', 'Created new chat with ID: ${newChat['id']}');
      return newChat;
    } catch (e) {
      _logOperation('Chats', 'Error getting or creating chat: $e', isError: true);
      return {};
    }
  }
  
  // Mark chat as read
  static Future<bool> markChatAsRead(int chatId) async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) return false;
      
      await supabase
          .from('messages')
          .update({'read': true})
          .eq('chat_id', chatId)
          .neq('sender_id', userId.toString());
          
      return true;
    } catch (e) {
      log('Error marking chat as read: $e');
      return false;
    }
  }
  
  // Get unread message count for the current user
  static Future<int> getUnreadMessageCount() async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) return 0;
      
      // First get all chats where the user is involved
      final chats = await supabase
          .from('chats')
          .select('id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');
      
      if (chats.isEmpty) return 0;
      
      final chatIds = chats.map((chat) => chat['id']).toList();
      
      // Then get unread messages in those chats where the user is not the sender
      final result = await supabase
          .from('messages')
          .select()
          .inFilter('chat_id', chatIds)
          .neq('sender_id', userId)
          .eq('read', false);
          
      return result.length;
    } catch (e) {
      _logOperation('Messages', 'Error getting unread message count: $e', isError: true);
      return 0;
    }
  }

  // SESSION OPERATIONS
  
  // Create session
  static Future<DatabaseResponse> createSession(Map<String, dynamic> sessionData) async {
    try {
      _logOperation('Sessions', 'Creating new session with data: $sessionData');
      
      // Validate required fields for session based on schema
      if (!sessionData.containsKey('requester_id') || 
          !sessionData.containsKey('provider_id') || 
          !sessionData.containsKey('skill_id')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (requester_id, provider_id, skill_id)'},
        );
      }
      
      // Ensure IDs are in the correct format (bigint in database)
      if (sessionData['requester_id'] is String) {
        try {
          sessionData['requester_id'] = int.parse(sessionData['requester_id']);
        } catch (e) {
          _logOperation('Sessions', 'Failed to convert requester_id to integer: ${sessionData['requester_id']}', isError: true);
        }
      }
      
      if (sessionData['provider_id'] is String) {
        try {
          sessionData['provider_id'] = int.parse(sessionData['provider_id']);
        } catch (e) {
          _logOperation('Sessions', 'Failed to convert provider_id to integer: ${sessionData['provider_id']}', isError: true);
        }
      }
      
      if (sessionData['skill_id'] is String) {
        try {
          sessionData['skill_id'] = int.parse(sessionData['skill_id']);
        } catch (e) {
          _logOperation('Sessions', 'Failed to convert skill_id to integer: ${sessionData['skill_id']}', isError: true);
        }
      }
      
      // Set default status if not provided
      if (!sessionData.containsKey('status')) {
        sessionData['status'] = 'Idle';
      }
      
      final result = await supabase
          .from('sessions')
          .insert(sessionData)
          .select()
          .single();
      
      _logOperation('Sessions', 'Session created successfully with ID: ${result['id']}');
      
      // Create a chat for this session if needed
      try {
        final chatData = {
          'user1_id': sessionData['requester_id'],
          'user2_id': sessionData['provider_id'],
          'session_id': result['id'],
          'last_updated': DateTime.now().toIso8601String(),
        };
        
        _logOperation('Sessions', 'Creating chat for session with data: $chatData');
        
        final chatResult = await supabase
            .from('chats')
            .insert(chatData)
            .select()
            .single();
            
        _logOperation('Sessions', 'Chat created successfully with ID: ${chatResult['id']}');
        
        // Include chat in the response
        result['chat'] = chatResult;
      } catch (chatError) {
        _logOperation('Sessions', 'Error creating chat for session: $chatError', isError: true);
        // Continue even if chat creation fails, the session was created
      }
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Sessions', 'Error creating session: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get session by ID
  static Future<DatabaseResponse> getSession(int sessionId) async {
    try {
      final data = await supabase
          .from('sessions')
          .select()
          .eq('id', sessionId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get session from chat
  static Future<DatabaseResponse> fetchSessionFromChat(int chatId) async {
    try {
      // First get the session_id from the chat
      final chatData = await supabase
          .from('chats')
          .select('session_id')
          .eq('id', chatId)
          .single();
          
      if (!chatData.containsKey('session_id') || chatData['session_id'] == null) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'No session found for this chat'},
        );
      }
      
      // Then get the session using that ID
      final sessionData = await supabase
          .from('sessions')
          .select()
          .eq('id', chatData['session_id'])
          .single();
          
      return DatabaseResponse(
        success: true,
        data: sessionData,
      );
    } catch (e) {
      _logOperation('Sessions', 'Error fetching session from chat: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Update session
  static Future<DatabaseResponse> updateSession(int sessionId, Map<String, dynamic> updates) async {
    try {
      await supabase
          .from('sessions')
          .update(updates)
          .eq('id', sessionId);
          
      final data = await supabase
          .from('sessions')
          .select()
          .eq('id', sessionId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get active sessions for user
  static Future<List<Map<String, dynamic>>> getActiveSessionsForUser(String userId) async {
    try {
      final data = await supabase
          .from('sessions')
          .select('*, skills(*)')
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .neq('status', 'Completed')
          .neq('status', 'Cancelled')
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error getting active sessions: $e');
      return [];
    }
  }
  
  // Complete session
  static Future<bool> completeSession(int sessionId) async {
    try {
      await supabase
          .from('sessions')
          .update({'status': 'Completed'})
          .eq('id', sessionId);
          
      return true;
    } catch (e) {
      log('Error completing session: $e');
      return false;
    }
  }
  
  // Cancel session
  static Future<bool> cancelSession(int sessionId) async {
    try {
      await supabase
          .from('sessions')
          .update({'status': 'Cancelled'})
          .eq('id', sessionId);
          
      return true;
    } catch (e) {
      log('Error cancelling session: $e');
      return false;
    }
  }

  // TRANSACTION OPERATIONS
  
  // Create transaction
  static Future<DatabaseResponse> createTransaction(Map<String, dynamic> transactionData) async {
    try {
      _logOperation('Transactions', 'Creating new transaction with data: $transactionData');
      
      // Validate required fields
      if (!transactionData.containsKey('requester_id') || 
          !transactionData.containsKey('provider_id') || 
          !transactionData.containsKey('session_id')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (requester_id, provider_id, session_id)'},
        );
      }
      
      // Ensure IDs are integers
      if (transactionData['requester_id'] is String) {
        try {
          transactionData['requester_id'] = int.parse(transactionData['requester_id']);
        } catch (e) {
          _logOperation('Transactions', 'Failed to convert requester_id to integer: ${transactionData['requester_id']}', isError: true);
        }
      }
      
      if (transactionData['provider_id'] is String) {
        try {
          transactionData['provider_id'] = int.parse(transactionData['provider_id']);
        } catch (e) {
          _logOperation('Transactions', 'Failed to convert provider_id to integer: ${transactionData['provider_id']}', isError: true);
        }
      }
      
      if (transactionData['session_id'] is String) {
        try {
          transactionData['session_id'] = int.parse(transactionData['session_id']);
        } catch (e) {
          _logOperation('Transactions', 'Failed to convert session_id to integer: ${transactionData['session_id']}', isError: true);
        }
      }
      
      final result = await supabase
          .from('transactions')
          .insert(transactionData)
          .select()
          .single();
      
      _logOperation('Transactions', 'Transaction created successfully with ID: ${result['id']}');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Transactions', 'Error creating transaction: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get user transactions (either as requester or provider)
  static Future<DatabaseResponse> getUserTransactions(dynamic userId) async {
    try {
      _logOperation('Transactions', 'Getting transactions for user: $userId');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Transactions', 'Failed to convert userId to integer: $userId', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Invalid userId format'},
          );
        }
      } else {
        parsedUserId = userId;
      }
      
      final data = await supabase
          .from('transactions')
          .select('''
            id, 
            created_at, 
            requester_id, 
            provider_id, 
            session_id,
            sessions:session_id (
              id, 
              status
            ),
            requester:requester_id (
              id, 
              username
            ),
            provider:provider_id (
              id, 
              username
            )
          ''')
          .or('requester_id.eq.$parsedUserId,provider_id.eq.$parsedUserId')
          .order('created_at', ascending: false);
      
      _logOperation('Transactions', 'Successfully retrieved ${data.length} transactions for user: $parsedUserId');
      
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      _logOperation('Transactions', 'Error getting user transactions: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get transaction by ID
  static Future<DatabaseResponse> getTransaction(int transactionId) async {
    try {
      final data = await supabase
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get transactions for session
  static Future<List<Map<String, dynamic>>> getSessionTransactions(int sessionId) async {
    try {
      final data = await supabase
          .from('transactions')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error getting session transactions: $e');
      return [];
    }
  }
  
  // Get transaction for a session
  static Future<DatabaseResponse> getTransactionFromSession(int sessionId) async {
    try {
      _logOperation('Transactions', 'Getting transaction for session: $sessionId');
      
      final data = await supabase
          .from('transactions')
          .select()
          .eq('session_id', sessionId)
          .limit(1);
      
      if (data.isEmpty) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'No transaction found for this session'},
        );
      }
      
      _logOperation('Transactions', 'Successfully retrieved transaction for session: $sessionId');
      
      return DatabaseResponse(
        success: true,
        data: data[0],
      );
    } catch (e) {
      _logOperation('Transactions', 'Error getting transaction for session: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Finalize a transaction
  static Future<DatabaseResponse> finalizeTransaction(int transactionId, String status) async {
    try {
      _logOperation('Transactions', 'Finalizing transaction $transactionId with status: $status');
      
      final result = await supabase
          .from('transactions')
          .update({
            'status': status,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId)
          .select()
          .single();
      
      _logOperation('Transactions', 'Transaction $transactionId finalized successfully');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Transactions', 'Error finalizing transaction: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // REPORT OPERATIONS
  
  // Create report
  static Future<DatabaseResponse> createReport(Map<String, dynamic> reportData) async {
    try {
      final data = await supabase
          .from('reports')
          .insert(reportData)
          .select()
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get report by ID
  static Future<DatabaseResponse> getReport(int reportId) async {
    try {
      final data = await supabase
          .from('reports')
          .select()
          .eq('id', reportId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Resolve report
  static Future<bool> resolveReport(int reportId) async {
    try {
      await supabase
          .from('reports')
          .update({'status': 'Resolved'})
          .eq('id', reportId);
          
      return true;
    } catch (e) {
      log('Error resolving report: $e');
      return false;
    }
  }
  
  // Get all reports
  static Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      final data = await supabase
          .from('reports')
          .select()
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('Error getting reports: $e');
      return [];
    }
  }

  // NOTIFICATION OPERATIONS
  
  // Get notifications for the current user
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) return [];
      
      final result = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      log('Error getting notifications: $e');
      return [];
    }
  }
  
  // Mark notification as read
  static Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
          
      return true;
    } catch (e) {
      log('Error marking notification as read: $e');
      return false;
    }
  }

  // Get current user from storage and database
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) {
        log('No stored user ID found');
        return null;
      }
      
      return await getUserById(userId);
    } catch (e) {
      log('Error getting current user: $e');
      return null;
    }
  }
  
  // Get user by ID
  static Future<Map<String, dynamic>?> getUserById(dynamic userId) async {
    try {
      log('Looking up user by ID: $userId');
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        log('Found user with ID: $userId');
        return response;
      } else {
        log('No user found with ID: $userId');
        return null;
      }
    } catch (e) {
      log('Error retrieving user by ID: $e');
      return null;
    }
  }

  // Update user profile
  static Future<DatabaseResponse> updateUserProfile(dynamic userId, Map<String, dynamic> userData) async {
    try {
      _logOperation('Users', 'Updating user profile for user: $userId with data: $userData');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Users', 'Failed to convert userId to integer: $userId', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Invalid userId format'},
          );
        }
      } else {
        parsedUserId = userId;
      }
      
      final result = await supabase
          .from('users')
          .update(userData)
          .eq('id', parsedUserId)
          .select()
          .single();
      
      _logOperation('Users', 'User profile updated successfully for user: $parsedUserId');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Users', 'Error updating user profile: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Add credits to user
  static Future<DatabaseResponse> addCreditsToUser(dynamic userId, int amount) async {
    try {
      _logOperation('Users', 'Adding $amount credits to user: $userId');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Users', 'Failed to convert userId to integer: $userId', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Invalid userId format'},
          );
        }
      } else {
        parsedUserId = userId;
      }
      
      // Get current credits
      final userData = await supabase
          .from('users')
          .select('credits')
          .eq('id', parsedUserId)
          .single();
      
      int currentCredits = userData['credits'] ?? 0;
      int newCredits = currentCredits + amount;
      
      _logOperation('Users', 'Current credits: $currentCredits, new credits: $newCredits');
      
      final result = await supabase
          .from('users')
          .update({'credits': newCredits})
          .eq('id', parsedUserId)
          .select()
          .single();
      
      _logOperation('Users', 'Credits updated successfully for user: $parsedUserId');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Users', 'Error adding credits: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Deduct credits from user
  static Future<DatabaseResponse> deductCreditsFromUser(dynamic userId, int amount) async {
    try {
      _logOperation('Users', 'Deducting $amount credits from user: $userId');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Users', 'Failed to convert userId to integer: $userId', isError: true);
          return DatabaseResponse(
            success: false,
            data: {'error': 'Invalid userId format'},
          );
        }
      } else {
        parsedUserId = userId;
      }
      
      // Get current credits
      final userData = await supabase
          .from('users')
          .select('credits')
          .eq('id', parsedUserId)
          .single();
      
      int currentCredits = userData['credits'] ?? 0;
      
      // Check if user has enough credits
      if (currentCredits < amount) {
        _logOperation('Users', 'Insufficient credits: current=$currentCredits, required=$amount', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Insufficient credits'},
        );
      }
      
      int newCredits = currentCredits - amount;
      
      _logOperation('Users', 'Current credits: $currentCredits, new credits: $newCredits');
      
      final result = await supabase
          .from('users')
          .update({'credits': newCredits})
          .eq('id', parsedUserId)
          .select()
          .single();
      
      _logOperation('Users', 'Credits updated successfully for user: $parsedUserId');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Users', 'Error deducting credits: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // Create a test user for development purposes
  static Future<LoginResponse> createTestUser() async {
    const email = 'test@example.com';
    const password = 'Test123!';
    const username = 'testuser';
    
    _logOperation('Test User Creation', 'Starting test user creation');
    
    try {
      // Check if test user already exists
      final existingUser = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (existingUser != null) {
        _logOperation('Test User Creation', 'Test user already exists, logging in');
        return await signInWithEmail(email, password);
      }
      
      // Create auth user
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create auth user');
      }

      final authId = authResponse.user!.id;
      
      // Create user profile
      final result = await supabase.from('users').insert({
        'username': username,
        'email': email,
        'password': password,
        'credits': 1000, // Give test user some initial credits
        'auth_id': authId,
        'moderator': true, // Make test user a moderator
      }).select();
      
      if (result.isEmpty) {
        throw Exception('Failed to create user profile');
      }

      final userId = result[0]['id'];
      await UserIdStorage.saveLoggedInUserId(userId);
      
      _logOperation('Test User Creation', 'Test user created successfully');
      
      return LoginResponse(
        success: true,
        message: 'Test user created and logged in',
        userId: userId,
      );
    } catch (e) {
      _logOperation('Test User Creation', 'Error: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Failed to create test user: $e',
      );
    }
  }

  // Utility method to fix existing users by creating auth users for them
  static Future<LoginResponse> fixExistingUser(String email, String newPassword) async {
    try {
      _logOperation('User Fix', 'Attempting to fix user with email: $email');
      
      // First check if user exists in database
      final dbUser = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();
      
      // Create auth user
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: newPassword,
        data: {
          'username': dbUser['username'],
          'db_user_id': dbUser['id'],
        },
      );

      if (authResponse.user == null) {
        return LoginResponse(
          success: false,
          message: 'Failed to create auth user',
        );
      }

      // Update the database user with the auth ID
      await supabase
          .from('users')
          .update({
            'auth_id': authResponse.user!.id,
            'password': newPassword,
          })
          .eq('id', dbUser['id']);
      
      _logOperation('User Fix', 'Successfully fixed user. Email: $email, ID: ${dbUser['id']}');
      
      // Log the user in
      return await signInWithEmail(email, newPassword);
      
    } catch (e) {
      _logOperation('User Fix', 'Error fixing user: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Error fixing user: $e',
      );
    }
  }

  // Get users that need authentication fixed (auth_id is null)
  static Future<List<Map<String, dynamic>>> getUsersNeedingAuthFix() async {
    try {
      _logOperation('User Fix', 'Fetching users that need authentication fixed');
      
      final response = await supabase
          .from('users')
          .select('id, username, email')
          .filter('auth_id', 'is', null);
      
      _logOperation('User Fix', 'Found ${response.length} users needing fix');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logOperation('User Fix', 'Error fetching users: $e', isError: true);
      return [];
    }
  }

  // Verify email
  static Future<bool> verifyEmail(String token, String type) async {
    try {
      _logOperation('Auth', 'Verifying email with token: $token, type: $type');
      
      if (type != 'signup' && type != 'recovery') {
        _logOperation('Auth', 'Invalid verification type: $type', isError: true);
        throw Exception('Invalid verification type');
      }
      
      await supabase.auth.verifyOTP(
        token: token,
        type: type == 'signup' ? OtpType.signup : OtpType.recovery,
      );
      
      _logOperation('Auth', 'Email verified successfully');
      return true;
    } catch (e) {
      _logOperation('Auth', 'Error verifying email: $e', isError: true);
      throw Exception('Failed to verify email: $e');
    }
  }

  // REVIEW OPERATIONS
  
  // Add a review
  static Future<DatabaseResponse> addReview(Map<String, dynamic> reviewData) async {
    try {
      _logOperation('Reviews', 'Adding review with data: $reviewData');
      
      // Validate required fields
      if (!reviewData.containsKey('session_id') || 
          !reviewData.containsKey('reviewer_id') || 
          !reviewData.containsKey('reviewee_id') ||
          !reviewData.containsKey('rating')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (session_id, reviewer_id, reviewee_id, rating)'},
        );
      }
      
      // Ensure IDs are integers
      if (reviewData['reviewer_id'] is String) {
        try {
          reviewData['reviewer_id'] = int.parse(reviewData['reviewer_id']);
        } catch (e) {
          _logOperation('Reviews', 'Failed to convert reviewer_id to integer: ${reviewData['reviewer_id']}', isError: true);
        }
      }
      
      if (reviewData['reviewee_id'] is String) {
        try {
          reviewData['reviewee_id'] = int.parse(reviewData['reviewee_id']);
        } catch (e) {
          _logOperation('Reviews', 'Failed to convert reviewee_id to integer: ${reviewData['reviewee_id']}', isError: true);
        }
      }
      
      if (reviewData['session_id'] is String) {
        try {
          reviewData['session_id'] = int.parse(reviewData['session_id']);
        } catch (e) {
          _logOperation('Reviews', 'Failed to convert session_id to integer: ${reviewData['session_id']}', isError: true);
        }
      }
      
      // Validate rating is between 1 and 5
      if (reviewData['rating'] < 1 || reviewData['rating'] > 5) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Rating must be between 1 and 5'},
        );
      }
      
      final result = await supabase
          .from('reviews')
          .insert(reviewData)
          .select()
          .single();
      
      _logOperation('Reviews', 'Review added successfully with ID: ${result['id']}');
      
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      _logOperation('Reviews', 'Error adding review: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get reviews for a user (as reviewee)
  static Future<List<Map<String, dynamic>>> getUserReviews(dynamic userId) async {
    try {
      _logOperation('Reviews', 'Getting reviews for user: $userId');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Reviews', 'Failed to convert userId to integer: $userId', isError: true);
          return [];
        }
      } else {
        parsedUserId = userId;
      }
      
      final data = await supabase
          .from('reviews')
          .select('''
            id, 
            rating, 
            review_text, 
            created_at,
            reviewer:reviewer_id (id, username),
            session:session_id (id)
          ''')
          .eq('reviewee_id', parsedUserId)
          .order('created_at', ascending: false);
      
      _logOperation('Reviews', 'Successfully retrieved ${data.length} reviews for user: $parsedUserId');
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _logOperation('Reviews', 'Error getting user reviews: $e', isError: true);
      return [];
    }
  }
  
  // Get average rating for a user
  static Future<double> getUserAverageRating(dynamic userId) async {
    try {
      _logOperation('Reviews', 'Getting average rating for user: $userId');
      
      // Ensure userId is an integer
      int parsedUserId;
      if (userId is String) {
        try {
          parsedUserId = int.parse(userId);
        } catch (e) {
          _logOperation('Reviews', 'Failed to convert userId to integer: $userId', isError: true);
          return 0.0;
        }
      } else {
        parsedUserId = userId;
      }
      
      final data = await supabase
          .from('reviews')
          .select('rating')
          .eq('reviewee_id', parsedUserId);
      
      if (data.isEmpty) {
        return 0.0;
      }
      
      double sum = 0;
      for (var review in data) {
        sum += (review['rating'] as int).toDouble();
      }
      
      final average = sum / data.length;
      _logOperation('Reviews', 'User $parsedUserId has average rating: $average from ${data.length} reviews');
      
      return average;
    } catch (e) {
      _logOperation('Reviews', 'Error getting user average rating: $e', isError: true);
      return 0.0;
    }
  }

  // Direct user registration to users table
  static Future<LoginResponse> registerUserDirect(String username, String email, String password) async {
    try {
      _logOperation('DirectRegistration', 'Starting direct user registration for: $email');
      
      // Check if username or email already exists
      final userExistsByUsername = await supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();
          
      if (userExistsByUsername != null) {
        _logOperation('DirectRegistration', 'Username already exists: $username', isError: true);
        return LoginResponse(
          success: false,
          message: 'Username already exists',
        );
      }
      
      final userExistsByEmail = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
          
      if (userExistsByEmail != null) {
        _logOperation('DirectRegistration', 'Email already exists: $email', isError: true);
        return LoginResponse(
          success: false,
          message: 'Email already exists',
        );
      }
      
      // Create user directly in the users table
      _logOperation('DirectRegistration', 'Creating user in database');
      final result = await supabase.from('users').insert({
        'username': username,
        'email': email,
        'password': password,
        'credits': 50, // Required per schema default
        'created_at': DateTime.now().toIso8601String(),
      }).select();
      
      _logOperation('DirectRegistration', 'User created successfully: $result');
      
      // Get the ID that was assigned
      if (result.isNotEmpty) {
        final userId = result[0]['id'];
        _logOperation('DirectRegistration', 'Database assigned user ID: $userId');
        
        // Store the user ID
        await UserIdStorage.saveLoggedInUserId(userId);
        
        return LoginResponse(
          success: true,
          message: 'User registered successfully',
          userId: userId,
        );
      } else {
        _logOperation('DirectRegistration', 'No result returned from user insertion', isError: true);
        return LoginResponse(
          success: false,
          message: 'User creation failed - no ID returned',
        );
      }
    } catch (e) {
      _logOperation('DirectRegistration', 'Error creating user: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Registration error: ${e.toString()}',
      );
    }
  }

  // Direct SQL registration
  static Future<LoginResponse> registerViaDirectSQL(String username, String email, String password) async {
    try {
      _logOperation('DirectSQL', 'Attempting direct SQL registration for: $email');
      
      // Check if username exists
      final usernameExists = await supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();
          
      if (usernameExists != null) {
        _logOperation('DirectSQL', 'Username already exists: $username', isError: true);
        return LoginResponse(
          success: false,
          message: 'Username already exists',
        );
      }
      
      // Check if email exists
      final emailExists = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
          
      if (emailExists != null) {
        _logOperation('DirectSQL', 'Email already exists: $email', isError: true);
        return LoginResponse(
          success: false,
          message: 'Email already exists',
        );
      }
      
      // Insert new user
      final result = await supabase
          .from('users')
          .insert({
            'username': username,
            'email': email,
            'password': password,
            'credits': 50,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select();
      
      _logOperation('DirectSQL', 'Registration result: $result');
      
      if (result.isNotEmpty) {
        final userId = result[0]['id'];
        
        // Store user ID
        await UserIdStorage.saveLoggedInUserId(userId);
        
        return LoginResponse(
          success: true,
          message: 'Registration successful',
          userId: userId,
        );
      } else {
        return LoginResponse(
          success: false,
          message: 'Failed to register user',
        );
      }
    } catch (e) {
      _logOperation('DirectSQL', 'Error during direct SQL registration: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Registration error: ${e.toString()}',
      );
    }
  }

  // AUTH OPERATIONS
  
  // Reset password
  static Future<void> resetPassword(String email) async {
    _logOperation('Password Reset', 'Sending password reset email to: $email');
    
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.sklr://reset-callback/',
      );
      _logOperation('Password Reset', 'Password reset email sent successfully');
    } catch (e) {
      _logOperation('Password Reset', 'Error sending password reset email: $e', isError: true);
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Update user credits
  static Future<bool> updateUserCredits(int userId, int credits) async {
    try {
      final response = await supabase
          .from('users') // Replace 'users' with the actual table name
          .update({'credits': credits})
          .eq('id', userId)
          .select();

      if (response.isEmpty) {
        if (kDebugMode) {
          print('Error updating user credits: No data returned.');
        }
        return false;
      }
      if (kDebugMode) {
        print('User credits updated successfully for user ID: $userId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Exception updating user credits: $e');
      }
      return false;
    }
  }
}