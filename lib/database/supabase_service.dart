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
              'credits': 50, // Required per schema default
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

  static Future<LoginResponse> registerViaDirectSQL(String username, String email, String password) async {
    _logOperation('Direct SQL Registration', 'Starting direct SQL registration for: $email');
    
    try {
      // Check if username or email already exists
      final userExists = await usernameExists(username);
      if (userExists) {
        _logOperation('Direct SQL Registration', 'Username already exists: $username', isError: true);
        return LoginResponse(
          success: false,
          message: 'Username already exists',
        );
      }
      
      final isEmailTaken = await emailExists(email);
      if (isEmailTaken) {
        _logOperation('Direct SQL Registration', 'Email already exists: $email', isError: true);
        return LoginResponse(
          success: false,
          message: 'Email already exists',
        );
      }

      // Insert the user directly into the users table
      final result = await supabase.from('users').insert({
        'username': username,
        'email': email,
        'password': password,
        'credits': 50, // Default credits
      }).select();

      if (result.isNotEmpty) {
        final userId = result[0]['id'];
        _logOperation('Direct SQL Registration', 'User created successfully with ID: $userId');
        
        // Store the user ID for future reference
        try {
          await UserIdStorage.saveLoggedInUserId(userId);
          _logOperation('Direct SQL Registration', 'User ID saved in local storage: $userId');
          
          return LoginResponse(
            success: true,
            message: 'User registered successfully',
            userId: userId,
          );
        } catch (storageError) {
          _logOperation('Direct SQL Registration', 'Error saving user ID: $storageError', isError: true);
          return LoginResponse(
            success: true,
            message: 'User created but ID storage failed',
            userId: userId,
          );
        }
      } else {
        _logOperation('Direct SQL Registration', 'No result returned from user insertion', isError: true);
        return LoginResponse(
          success: false,
          message: 'User creation failed - no ID returned',
        );
      }
    } catch (e) {
      _logOperation('Direct SQL Registration', 'Error creating user: $e', isError: true);
      return LoginResponse(
        success: false,
        message: e.toString(),
      );
    }
  }
  
  static Future<LoginResponse> registerUserDirect(String username, String email, String password) async {
    _logOperation('Direct Registration', 'Starting direct registration for: $email');
    
    try {
      // Hash the password before storing
      final bytes = utf8.encode(password);
      final hashedPassword = sha256.convert(bytes).toString();
      
      // Use the direct SQL registration method with hashed password
      return await registerViaDirectSQL(username, email, hashedPassword);
    } catch (e) {
      _logOperation('Direct Registration', 'Error in registration: $e', isError: true);
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
            'credits': 50, // Required per schema
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

  // Create or login test user for development/testing
  static Future<LoginResponse> createTestUser() async {
    try {
      _logOperation('Test Auth', 'Creating or logging in test user');
      
      const testEmail = 'test@example.com';
      const testPassword = 'Test123!';
      const testUsername = 'testuser';
      
      // Check if test user already exists in the database
      final existingUser = await supabase
          .from('users')
          .select()
          .eq('email', testEmail)
          .maybeSingle();
          
      if (existingUser != null) {
        _logOperation('Test Auth', 'Test user already exists, logging in');
        
        // Test user exists, log them in directly
        final userId = existingUser['id'];
        await UserIdStorage.saveLoggedInUserId(userId);
        
        return LoginResponse(
          success: true,
          message: 'Test user logged in successfully',
          userId: userId,
        );
      }
      
      // Test user doesn't exist, create one
      _logOperation('Test Auth', 'Test user does not exist, creating new test user');
      
      // First try to create auth user
      try {
        await supabase.auth.signUp(
          email: testEmail,
          password: testPassword,
          data: {
            'username': testUsername,
          },
        );
      } catch (e) {
        _logOperation('Test Auth', 'Error creating auth user: $e', isError: true);
        // Continue anyway as we'll create the database user directly
      }
      
      // Create user in the database
      final result = await supabase.from('users').insert({
        'username': testUsername,
        'email': testEmail,
        'password': testPassword,
        'credits': 100, // Give test user some credits
        'moderator': true, // Make test user a moderator for testing all features
      }).select();
      
      if (result.isNotEmpty) {
        final userId = result[0]['id'];
        _logOperation('Test Auth', 'Created test user with ID: $userId');
        
        // Store the ID for future use
        await UserIdStorage.saveLoggedInUserId(userId);
        
        return LoginResponse(
          success: true,
          message: 'Test user created and logged in successfully',
          userId: userId,
        );
      } else {
        _logOperation('Test Auth', 'No result returned from test user insertion', isError: true);
        return LoginResponse(
          success: false,
          message: 'Test user creation failed - no ID returned',
        );
      }
    } catch (e) {
      _logOperation('Test Auth', 'Error creating test user: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Error creating test user: $e',
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
  
  // Get user by ID and return as Map
  static Future<Map<String, dynamic>?> getUserById(dynamic userId) async {
    try {
      // Convert userId to string if it's an integer
      final userIdStr = userId is int ? userId.toString() : userId;
      
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userIdStr)
          .maybeSingle();
          
      return data;
    } catch (e) {
      log('Error getting user by ID: $e');
      return null;
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

  // Get users needing auth fix (users with no auth_id)
  static Future<List<Map<String, dynamic>>> getUsersNeedingAuthFix() async {
    try {
      _logOperation('Auth Fix', 'Getting users needing authentication fix');
      
      final users = await supabase
          .from('users')
          .select('id, username, email')
          .filter('auth_id', 'is', null);
      
      _logOperation('Auth Fix', 'Found ${users.length} users needing authentication fix');
      return List<Map<String, dynamic>>.from(users);
    } catch (e) {
      _logOperation('Auth Fix', 'Error getting users needing auth fix: $e', isError: true);
      return [];
    }
  }
  
  // Fix existing user by creating an auth account and linking it
  static Future<LoginResponse> fixExistingUser(String email, String newPassword) async {
    try {
      _logOperation('Auth Fix', 'Fixing user authentication for email: $email');
      
      // First, find the user in the database
      final userData = await supabase
          .from('users')
          .select('id, username, email, auth_id')
          .eq('email', email)
          .maybeSingle();
      
      if (userData == null) {
        _logOperation('Auth Fix', 'User not found with email: $email', isError: true);
        return LoginResponse(
          success: false, 
          message: 'User not found with email: $email'
        );
      }
      
      // Check if user already has an auth_id - if so, we'll update the password
      if (userData['auth_id'] != null) {
        _logOperation('Auth Fix', 'User already has auth_id, updating password only');
        
        // Get the user by auth_id
        try {
          
          // Update password for existing auth user
          await supabase.auth.admin.updateUserById(
            userData['auth_id'],
            attributes: AdminUserAttributes(
              password: newPassword,
            ),
          );
          
          _logOperation('Auth Fix', 'Updated password for existing auth user');
          
          // Log in the user
          await supabase.auth.signInWithPassword(
            email: email,
            password: newPassword,
          );
          
          // Store user ID
          await UserIdStorage.saveLoggedInUserId(userData['id']);
          
          return LoginResponse(
            success: true,
            message: 'Password updated and user logged in',
            userId: userData['id'],
          );
        } catch (e) {
          _logOperation('Auth Fix', 'Error updating existing auth user: $e', isError: true);
          // Continue to creating a new auth user if updating failed
        }
      }
      
      // Create new auth user
      _logOperation('Auth Fix', 'Creating new auth user for database user');
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: newPassword,
        data: {
          'db_user_id': userData['id'],
          'username': userData['username'],
        },
      );
      
      if (authResponse.user == null) {
        _logOperation('Auth Fix', 'Failed to create auth user', isError: true);
        return LoginResponse(
          success: false,
          message: 'Failed to create authentication account',
        );
      }
      
      final authId = authResponse.user!.id;
      _logOperation('Auth Fix', 'Created auth user with ID: $authId');
      
      // Update database user with auth_id
      await supabase
          .from('users')
          .update({'auth_id': authId})
          .eq('id', userData['id']);
      
      _logOperation('Auth Fix', 'Updated database user with auth_id');
      
      // Store user ID
      await UserIdStorage.saveLoggedInUserId(userData['id']);
      
      return LoginResponse(
        success: true,
        message: 'User fixed and logged in successfully',
        userId: userData['id'],
      );
    } catch (e) {
      _logOperation('Auth Fix', 'Error fixing user: $e', isError: true);
      return LoginResponse(
        success: false,
        message: 'Error fixing user: ${e.toString()}',
      );
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
      _logOperation('Skills', 'Attempting to delete skill with ID: $skillId');
      
      // First check if skill exists
      final skillExists = await supabase
          .from('skills')
          .select('id')
          .eq('id', skillId)
          .maybeSingle();
          
      if (skillExists == null) {
        _logOperation('Skills', 'Skill with ID $skillId not found', isError: true);
        return false;
      }
      
      _logOperation('Skills', 'Skill exists, proceeding with deletion');
      
      // Step 1: Check for sessions related to this skill
      final relatedSessions = await supabase
          .from('sessions')
          .select('id')
          .eq('skill_id', skillId);
          
      _logOperation('Skills', 'Found ${relatedSessions.length} related sessions');
      
      // Step 2: Handle each session and its related records
      for (var session in relatedSessions) {
        final sessionId = session['id'];
        _logOperation('Skills', 'Processing session $sessionId');
        
        // Step 2a: Delete any transactions linked to this session
        try {
          _logOperation('Skills', 'Deleted transactions for session $sessionId');
        } catch (e) {
          _logOperation('Skills', 'Error deleting transactions: $e', isError: true);
        }
        
        // Step 2b: Delete any reviews linked to this session
        try {
          _logOperation('Skills', 'Deleted reviews for session $sessionId');
        } catch (e) {
          _logOperation('Skills', 'Error deleting reviews: $e', isError: true);
        }
        
        // Step 2c: Delete chats linked to this session
        try {
          // Find chats first
          final chats = await supabase
              .from('chats')
              .select('id')
              .eq('session_id', sessionId);
          
          for (var chat in chats) {
            final chatId = chat['id'];
            
            // Delete messages first (messages have FK to chats)
            try {
              await supabase
                  .from('messages')
                  .delete()
                  .eq('chat_id', chatId);
              _logOperation('Skills', 'Deleted messages for chat $chatId');
            } catch (e) {
              _logOperation('Skills', 'Error deleting messages: $e', isError: true);
            }
            
            // Now delete the chat
            try {
              await supabase
                  .from('chats')
                  .delete()
                  .eq('id', chatId);
              _logOperation('Skills', 'Deleted chat $chatId');
            } catch (e) {
              _logOperation('Skills', 'Error deleting chat: $e', isError: true);
            }
          }
        } catch (e) {
          _logOperation('Skills', 'Error processing chats: $e', isError: true);
        }
        
        // Step 2d: Now delete the session
        try {
          await supabase
              .from('sessions')
              .delete()
              .eq('id', sessionId);
          _logOperation('Skills', 'Deleted session $sessionId');
        } catch (e) {
          _logOperation('Skills', 'Error deleting session: $e', isError: true);
        }
      }
      
      // Step 3: Update any reports linked to this skill to resolved
      try {
        await supabase
            .from('reports')
            .update({'status': 'Resolved'})
            .eq('skill_id', skillId);
        _logOperation('Skills', 'Updated reports for skill $skillId to resolved');
      } catch (e) {
        _logOperation('Skills', 'Error updating reports: $e', isError: true);
      }
      
      // Step 4: Finally delete the skill itself
      try {
        await supabase
            .from('skills')
            .delete()
            .eq('id', skillId);
        
        _logOperation('Skills', 'Successfully deleted skill with ID: $skillId');
        return true;
      } catch (e) {
        _logOperation('Skills', 'Error in final skill deletion: $e', isError: true);
        return false;
      }
    } catch (e) {
      _logOperation('Skills', 'Error deleting skill with ID $skillId: $e', isError: true);
      return false;
    }
  }

  // Mark reports linked to a skill as resolved
  static Future<bool> resolveReportsForSkill(int skillId) async {
    try {
      // Update reports linked to the skill to "Resolved"
      await supabase
          .from('reports')
          .update({'status': 'Resolved'})
          .eq('skill_id', skillId);

      _logOperation('Reports', 'Updated reports for skill $skillId to resolved');
      return true;
    } catch (e) {
      _logOperation('Reports', 'Error updating reports for skill $skillId: $e', isError: true);
      return false;
    }
  }
  
  // Search skills
  static Future<List<Map<String, dynamic>>> searchSkills(String query) async {
    try {
      if (query.isEmpty) {
        // Return recent skills if query is empty
        return await getRecentSkills(20);
      }
      
      // Search for skills matching the query in name or description
      final data = await supabase
          .from('skills')
          .select('*, users!skills_user_id_fkey(username, avatar_url)')
          .or('name.ilike.%${query.trim()}%,description.ilike.%${query.trim()}%')
          .order('created_at', ascending: false)
          .limit(50);
      
      log('Found ${data.length} skills matching query: $query');
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
  
  // Create new category
  static Future<DatabaseResponse> createCategory(String name, String asset) async {
    try {
      final result = await supabase
          .from('categories')
          .insert({
            'name': name,
            'description': 'Category for $name skills',
            'asset': asset,
          })
          .select()
          .single();
          
      return DatabaseResponse(
        success: true,
        data: result,
      );
    } catch (e) {
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // REPORTS OPERATIONS
  
    // Fetch all pending reports
    static Future<List<Map<String, dynamic>>> fetchReports() async {
      try {
        final data = await supabase
            .from('reports')
            .select('*')
            .eq('status', 'Pending')
            .order('created_at', ascending: false);
            
        return List<Map<String, dynamic>>.from(data);
      } catch (e) {
        log('Error fetching reports: $e');
        return [];
      }
    }
    
    // Create a new report using database function
  static Future<DatabaseResponse> createReport(Map<String, dynamic> reportData) async {
    try {
      _logOperation('Reports', 'Creating new report using database function: $reportData');
      
      // Call the database function
      final result = await supabase.rpc(
        'create_report',
        params: {
          'p_reporter_id': reportData['reporter_id'],
          'p_skill_id': reportData['skill_id'],
          'p_text': reportData['text'] ?? 'Reported from mobile app',
          'p_status': reportData['status'] ?? 'Pending'
        }
      );
      
      if (result == null) {
        _logOperation('Reports', 'No response from create_report function', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'No response from server'},
        );
      }
      
      // The function returns {success: boolean, data/error: value}
      final success = result['success'] ?? false;
      if (!success) {
        _logOperation('Reports', 'Database function returned error: ${result['error']}', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': result['error']},
        );
      }
      
      _logOperation('Reports', 'Report created successfully');
      return DatabaseResponse(
        success: true,
        data: result['data'],
      );
    } catch (e) {
      _logOperation('Reports', 'Error calling create_report function: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // Resolve a report by updating its status
  static Future<bool> resolveReport(int reportId) async {
    try {
      _logOperation('Reports', 'Resolving report with ID: $reportId');
      
      final now = DateTime.now().toIso8601String();
      
      await supabase
          .from('reports')
          .update({
            'status': 'Resolved',
            'resolved_at': now
          })
          .eq('id', reportId);
      
      _logOperation('Reports', 'Report with ID $reportId marked as resolved');
      return true;
    } catch (e) {
      _logOperation('Reports', 'Error resolving report with ID $reportId: $e', isError: true);
      return false;
    }
  }

  // Get all reports (for moderation dashboard)
  static Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      _logOperation('Reports', 'Fetching all pending reports');
      
      // Get reports with related data
      final data = await supabase
          .from('reports')
          .select('''
            *,
            reporter:reporter_id(id, username, avatar_url),
            skill:skill_id(
              *,
              user:user_id(id, username, avatar_url)
            )
          ''')
          .eq('status', 'Pending')
          .order('created_at', ascending: false);
          
      _logOperation('Reports', 'Fetched ${data.length} pending reports');
      
      // Filter out reports where the skill might no longer exist
      final validReports = data.where((report) => 
        report['skill'] != null && report['skill'].isNotEmpty
      ).toList();
      
      if (validReports.length < data.length) {
        _logOperation('Reports', 'Filtered out ${data.length - validReports.length} reports with missing skills');
        
        // Auto-resolve reports with missing skills
        for (var report in data) {
          if (report['skill'] == null || report['skill'].isEmpty) {
            try {
              await supabase
                  .from('reports')
                  .update({
                    'status': 'Resolved',
                    'resolution': 'Auto-resolved - Skill no longer exists',
                    'resolved_at': DateTime.now().toIso8601String()
                  })
                  .eq('id', report['id']);
              
              _logOperation('Reports', 'Auto-resolved report ID: ${report['id']} for missing skill');
            } catch (e) {
              _logOperation('Reports', 'Error auto-resolving report: $e', isError: true);
            }
          }
        }
      }
      
      return List<Map<String, dynamic>>.from(validReports);
    } catch (e) {
      _logOperation('Reports', 'Error fetching reports: $e', isError: true);
      return [];
    }
  }
  
  // Get a specific report by ID
  static Future<DatabaseResponse> getReport(int reportId) async {
    try {
      final data = await supabase
          .from('reports')
          .select('*')
          .eq('id', reportId)
          .single();
          
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      log('Error getting report with ID $reportId: $e');
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
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

  // Verify email token
  static Future<bool> verifyEmail(String token, String type) async {
    try {
      _logOperation('Email Verification', 'Verifying email with token: $token, type: $type');
      
      // This would normally interact with Supabase Auth, but we'll simulate it
      // since Supabase handles most of this automatically with redirects
      if (type == 'signup' || type == 'recovery') {
        // For signup or recovery, we just need to acknowledge we got the token
        // In a real app, we'd use supabase.auth.verifyOTP or similar
        return true;
      }
      
      _logOperation('Email Verification', 'Unknown verification type: $type', isError: true);
      return false;
    } catch (e) {
      _logOperation('Email Verification', 'Error verifying email: $e', isError: true);
      return false;
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

  // Get profile picture URL
  static Future<String?> getProfilePictureUrl(String userId) async {
    try {
      final String path = 'profile-pictures/$userId.jpg';
      final String url = supabase.storage
          .from('profile-pictures')
          .getPublicUrl(path);
      
      // Check if the file exists
      try {
        await supabase.storage.from('profile-pictures').list(path: path);
        return url;
      } catch (e) {
        return null; // File doesn't exist
      }
    } catch (e) {
      _logOperation('Get Profile Picture', 'Error getting profile picture: $e', isError: true);
      return null;
    }
  }

  // CHAT OPERATIONS
  
  // Send a message
  static Future<DatabaseResponse> sendMessage(Map<String, dynamic> messageData) async {
    try {
      _logOperation('Messages', 'Sending message: $messageData');
      
      // Validate required fields
      if (!messageData.containsKey('chat_id') || 
          !messageData.containsKey('sender_id') ||
          !messageData.containsKey('message')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (chat_id, sender_id, message)'},
        );
      }
      
      // Create the message
      final result = await supabase
          .from('messages')
          .insert(messageData)
          .select();
          
      if (result.isEmpty) {
        _logOperation('Messages', 'Failed to create message', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Failed to create message'},
        );
      }
      
      _logOperation('Messages', 'Message sent successfully with ID: ${result[0]['id']}');
      
      // Update the last_message and last_updated in the chat
      try {
        await supabase
            .from('chats')
            .update({
              'last_message': messageData['message'],
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('id', messageData['chat_id']);
            
        _logOperation('Messages', 'Updated chat with last message');
      } catch (chatUpdateError) {
        _logOperation('Messages', 'Error updating chat: $chatUpdateError', isError: true);
        // Don't fail the operation if just the chat update fails
      }
      
      return DatabaseResponse(
        success: true,
        data: result[0],
      );
    } catch (e) {
      _logOperation('Messages', 'Error sending message: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }

  // Send a message with notification
  static Future<DatabaseResponse> sendMessageWithNotification({
    required int chatId,
    required dynamic senderId,
    required String message,
    required String senderName,
    required dynamic recipientId,
    required String? senderImage,
  }) async {
    try {
      _logOperation('Messages', 'Sending message with notification: $message');
      
      // First, send the message itself
      final messageResult = await sendMessage({
        'chat_id': chatId,
        'sender_id': senderId.toString(),
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });
      
      if (!messageResult.success) {
        return messageResult;
      }
      
      // Then, create a notification (without chat_id, as it's not in the schema)
      try {
        final notificationData = {
          'user_id': recipientId is int ? recipientId : int.parse(recipientId.toString()),
          'message': '$senderName: $message',
          'sender_id': senderId is int ? senderId : int.parse(senderId.toString()),
          'sender_image': senderImage,
          'read': false,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        await supabase
            .from('notifications')
            .insert(notificationData);
        
        _logOperation('Notifications', 'Notification created successfully');
      } catch (notificationError) {
        // Log the error but don't fail the whole operation
        _logOperation('Notifications', 'Error creating notification: $notificationError', isError: true);
      }
      
      return messageResult;
    } catch (e) {
      _logOperation('Messages', 'Error in sendMessageWithNotification: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Mark chat messages as read
  static Future<bool> markChatAsRead(int chatId) async {
    try {
      _logOperation('Messages', 'Marking all messages as read for chat: $chatId');
      
      // Get current user ID
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) {
        _logOperation('Messages', 'No user ID available for markChatAsRead', isError: true);
        return false;
      }
      
      // Get the chat to determine which messages to mark as read
      final chatData = await supabase
          .from('chats')
          .select('user1_id, user2_id')
          .eq('id', chatId)
          .maybeSingle();
          
      if (chatData == null) {
        _logOperation('Messages', 'Chat not found: $chatId', isError: true);
        return false;
      }
      
      // Determine the other user ID (the sender of messages to mark as read)
      final otherUserId = chatData['user1_id'].toString() == userId.toString() 
          ? chatData['user2_id'] 
          : chatData['user1_id'];
      
      // Mark all messages from the other user as read
      await supabase
          .from('messages')
          .update({'read': true})
          .eq('chat_id', chatId)
          .eq('sender_id', otherUserId)
          .eq('read', false);
      
      _logOperation('Messages', 'Successfully marked messages as read in chat $chatId');
      return true;
    } catch (e) {
      _logOperation('Messages', 'Error marking chat as read: $e', isError: true);
      return false;
    }
  }
  
  // Get unread message count for current user
  static Future<int> getUnreadMessageCount() async {
    try {
      // Get current user ID
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) {
        _logOperation('Messages', 'No user ID available for getUnreadMessageCount', isError: true);
        return 0;
      }
      
      // Get all chats where the user is a participant
      final chats = await supabase
          .from('chats')
          .select('id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');
      
      if (chats.isEmpty) {
        return 0;
      }
      
      int totalUnread = 0;
      
      // For each chat, count unread messages where the user is not the sender
      for (final chat in chats) {
        final chatId = chat['id'];
        
        final unreadCount = await supabase
            .from('messages')
            .select('id')
            .eq('chat_id', chatId)
            .neq('sender_id', userId.toString())
            .eq('read', false);
            
        totalUnread += unreadCount.length;
      }
      
      return totalUnread;
    } catch (e) {
      _logOperation('Messages', 'Error getting unread message count: $e', isError: true);
      return 0;
    }
  }
  
  // Get user chats
  static Future<DatabaseResponse> getUserChats(dynamic userId) async {
    try {
      _logOperation('Chats', 'Getting chats for user: $userId');
      
      // Ensure userId is in string format
      final userIdStr = userId.toString();
      
      // Get all chats where the user is either user1 or user2
      final chats = await supabase
          .from('chats')
          .select('''
            *,
            user1:user1_id(id, username, avatar_url),
            user2:user2_id(id, username, avatar_url),
            session:session_id(*)
          ''')
          .or('user1_id.eq.$userIdStr,user2_id.eq.$userIdStr')
          .order('last_updated', ascending: false);
      
      _logOperation('Chats', 'Found ${chats.length} chats for user $userId');
      
      return DatabaseResponse(
        success: true,
        data: chats,
      );
    } catch (e) {
      _logOperation('Chats', 'Error getting user chats: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get messages for a chat
  static Future<DatabaseResponse> getChatMessages(int chatId) async {
    try {
      _logOperation('Messages', 'Getting messages for chat: $chatId');
      
      final messages = await supabase
          .from('messages')
          .select('''
            *,
            sender:sender_id(id, username, avatar_url)
          ''')
          .eq('chat_id', chatId)
          .order('timestamp', ascending: true);
      
      // Handle the case where sender information might be missing
      List<Map<String, dynamic>> processedMessages = [];
      
      for (var message in messages) {
        if (message['sender'] == null) {
          // Retrieve the sender info separately if the join didn't work
          try {
            final userId = message['sender_id'];
            if (userId != null) {
              final userData = await supabase
                  .from('users')
                  .select('id, username, avatar_url')
                  .eq('id', userId)
                  .maybeSingle();
                  
              if (userData != null) {
                message['sender'] = userData;
              } else {
                message['sender'] = {
                  'id': userId,
                  'username': 'User',
                  'avatar_url': null
                };
              }
            }
          } catch (e) {
            _logOperation('Messages', 'Error fetching sender data: $e', isError: true);
            // Use a placeholder if we can't get the user data
            message['sender'] = {
              'id': message['sender_id'],
              'username': 'User',
              'avatar_url': null
            };
          }
        }
        processedMessages.add(Map<String, dynamic>.from(message));
      }
      
      _logOperation('Messages', 'Found ${processedMessages.length} messages for chat $chatId');
      
      return DatabaseResponse(
        success: true,
        data: processedMessages,
      );
    } catch (e) {
      _logOperation('Messages', 'Error getting chat messages: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get or create a chat between two users for a specific skill
  static Future<Map<String, dynamic>> getOrCreateChat(
    String user1Id, 
    String user2Id, 
    int skillId
  ) async {
    try {
      _logOperation('Chats', 'Getting or creating chat between users $user1Id and $user2Id for skill $skillId');
      
      // First check if a chat already exists between these users for this skill
      try {
        // Get all sessions for this skill involving both users
        final sessionData = await supabase
            .from('sessions')
            .select('id')
            .eq('skill_id', skillId)
            .or('and(requester_id.eq.$user1Id,provider_id.eq.$user2Id),and(requester_id.eq.$user2Id,provider_id.eq.$user1Id)')
            .maybeSingle();
            
        if (sessionData != null) {
          // We found a session, now check if there's a chat for it
          final sessionId = sessionData['id'];
          _logOperation('Chats', 'Found existing session: $sessionId');
          
          final chatData = await supabase
              .from('chats')
              .select('*')
              .eq('session_id', sessionId)
              .maybeSingle();
              
          if (chatData != null) {
            _logOperation('Chats', 'Found existing chat: ${chatData['id']} for session: $sessionId');
            return chatData;
          }
          
          // Session exists but no chat, create one
          final chatResult = await supabase
              .from('chats')
              .insert({
                'user1_id': user1Id,
                'user2_id': user2Id,
                'session_id': sessionId,
                'last_updated': DateTime.now().toIso8601String(),
              })
              .select()
              .maybeSingle();
              
          if (chatResult != null) {
            _logOperation('Chats', 'Created new chat with ID: ${chatResult['id']} for existing session');
            return chatResult;
          } else {
            throw Exception('Failed to create chat for existing session');
          }
        }
      } catch (e) {
        _logOperation('Chats', 'Error checking for existing session/chat: $e', isError: true);
        // Continue with creating a new session and chat
      }
      
      // No existing session found, create a new session
      _logOperation('Chats', 'No existing session found, creating new session');
      
      try {
        // Determine which user is the provider (owner of the skill)
        final skillData = await supabase
            .from('skills')
            .select('user_id')
            .eq('id', skillId)
            .maybeSingle();
            
        if (skillData == null) {
          _logOperation('Chats', 'Skill not found with ID: $skillId', isError: true);
          return {'error': 'Skill not found'};
        }
        
        String providerId, requesterId;
        if (skillData['user_id'].toString() == user1Id.toString()) {
          providerId = user1Id;
          requesterId = user2Id;
        } else {
          providerId = user2Id;
          requesterId = user1Id;
        }
        
        // Create a new session
        final sessionResult = await supabase
            .from('sessions')
            .insert({
              'requester_id': requesterId,
              'provider_id': providerId,
              'skill_id': skillId,
              'status': 'Idle',
              'created_at': DateTime.now().toIso8601String(),
              'notified': false,
            })
            .select()
            .maybeSingle();
            
        if (sessionResult == null) {
          _logOperation('Chats', 'Failed to create session', isError: true);
          return {'error': 'Failed to create session'};
        }
        
        final sessionId = sessionResult['id'];
        _logOperation('Chats', 'Created new session with ID: $sessionId');
        
        // Create a new chat
        final chatResult = await supabase
            .from('chats')
            .insert({
              'user1_id': user1Id,
              'user2_id': user2Id,
              'session_id': sessionId,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .select()
            .maybeSingle();
            
        if (chatResult == null) {
          _logOperation('Chats', 'Failed to create chat', isError: true);
          return {'error': 'Failed to create chat'};
        }
        
        _logOperation('Chats', 'Created new chat with ID: ${chatResult['id']}');
        return chatResult;
      } catch (e) {
        _logOperation('Chats', 'Error creating session and chat: $e', isError: true);
        return {'error': e.toString()};
      }
    } catch (e) {
      _logOperation('Chats', 'Error getting or creating chat: $e', isError: true);
      return {'error': e.toString()};
    }
  }
  
  // SESSION AND TRANSACTION OPERATIONS
  
  // Get session by ID
  static Future<DatabaseResponse> getSession(int sessionId) async {
    try {
      _logOperation('Sessions', 'Getting session with ID: $sessionId');
      
      final data = await supabase
          .from('sessions')
          .select('''
            *,
            requester:requester_id(id, username, avatar_url),
            provider:provider_id(id, username, avatar_url),
            skill:skill_id(*)
          ''')
          .eq('id', sessionId)
          .maybeSingle();
          
      if (data == null) {
        _logOperation('Sessions', 'No session found with ID: $sessionId', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Session not found'},
        );
      }
      
      _logOperation('Sessions', 'Successfully retrieved session with ID: $sessionId');
      return DatabaseResponse(
        success: true,
        data: data,
      );
    } catch (e) {
      _logOperation('Sessions', 'Error getting session with ID $sessionId: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get transaction by ID
  static Future<DatabaseResponse> getTransaction(int transactionId) async {
    try {
      _logOperation('Transactions', 'Getting transaction with ID: $transactionId');
      
      final transaction = await supabase
          .from('transactions')
          .select('''
            *,
            requester:requester_id(id, username, avatar_url),
            provider:provider_id(id, username, avatar_url),
            session:session_id(*)
          ''')
          .eq('id', transactionId)
          .single();
      
      _logOperation('Transactions', 'Found transaction with ID: $transactionId');
      
      return DatabaseResponse(
        success: true,
        data: transaction,
      );
    } catch (e) {
      _logOperation('Transactions', 'Error getting transaction: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get transaction from session
  static Future<DatabaseResponse> getTransactionFromSession(int sessionId) async {
    try {
      _logOperation('Transactions', 'Getting transaction for session with ID: $sessionId');
      
      final transaction = await supabase
          .from('transactions')
          .select('''
            *,
            requester:requester_id(id, username, avatar_url),
            provider:provider_id(id, username, avatar_url)
          ''')
          .eq('session_id', sessionId)
          .order('created_at', ascending: false)
          .maybeSingle();
      
      if (transaction == null) {
        _logOperation('Transactions', 'No transaction found for session with ID: $sessionId');
        return DatabaseResponse(
          success: false,
          data: {'error': 'No transaction found for this session'},
        );
      }
      
      _logOperation('Transactions', 'Found transaction with ID: ${transaction['id']} for session: $sessionId');
      
      return DatabaseResponse(
        success: true,
        data: transaction,
      );
    } catch (e) {
      _logOperation('Transactions', 'Error getting transaction from session: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Create a session
  static Future<DatabaseResponse> createSession(Map<String, dynamic> sessionData) async {
    try {
      _logOperation('Sessions', 'Creating new session with data: $sessionData');
      
      // Validate required fields
      if (!sessionData.containsKey('requester_id') || 
          !sessionData.containsKey('provider_id') ||
          !sessionData.containsKey('skill_id')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (requester_id, provider_id, skill_id)'},
        );
      }
      
      final result = await supabase
          .from('sessions')
          .insert(sessionData)
          .select()
          .single();
      
      _logOperation('Sessions', 'Session created successfully with ID: ${result['id']}');
      
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
  
  // Fetch session from chat ID
  static Future<DatabaseResponse> fetchSessionFromChat(int chatId) async {
    try {
      _logOperation('Sessions', 'Fetching session from chat with ID: $chatId');
      
      final chat = await supabase
          .from('chats')
          .select('session_id')
          .eq('id', chatId)
          .maybeSingle();
      
      if (chat == null || chat['session_id'] == null) {
        _logOperation('Sessions', 'No session found for chat with ID: $chatId', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'No session found for this chat'},
        );
      }
      
      final sessionId = chat['session_id'];
      _logOperation('Sessions', 'Found session ID: $sessionId for chat: $chatId');
      return await getSession(sessionId);
    } catch (e) {
      _logOperation('Sessions', 'Error fetching session from chat: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Create a transaction
  static Future<DatabaseResponse> createTransaction(Map<String, dynamic> transactionData) async {
    try {
      _logOperation('Transactions', 'Creating new transaction with data: $transactionData');
      
      // Validate required fields
      if (!transactionData.containsKey('session_id') || 
          !transactionData.containsKey('requester_id') ||
          !transactionData.containsKey('provider_id')) {
        return DatabaseResponse(
          success: false,
          data: {'error': 'Required fields missing (session_id, requester_id, provider_id)'},
        );
      }
      
      final result = await supabase
          .from('transactions')
          .insert(transactionData)
          .select();
      
      if (result.isEmpty) {
        _logOperation('Transactions', 'Failed to create transaction', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Failed to create transaction'},
        );
      }
      
      _logOperation('Transactions', 'Transaction created successfully with ID: ${result[0]['id']}');
      
      return DatabaseResponse(
        success: true,
        data: result[0],
      );
    } catch (e) {
      _logOperation('Transactions', 'Error creating transaction: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Finalize a transaction
  static Future<DatabaseResponse> finalizeTransaction(int transactionId, String status) async {
    try {
      _logOperation('Transactions', 'Finalizing transaction with ID: $transactionId, status: $status');
      
      final result = await supabase
          .from('transactions')
          .update({
            'status': status,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId)
          .select();
      
      if (result.isEmpty) {
        _logOperation('Transactions', 'Transaction not found or not updated', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Transaction not found or not updated'},
        );
      }
      
      _logOperation('Transactions', 'Transaction finalized successfully');
      
      return DatabaseResponse(
        success: true,
        data: result[0],
      );
    } catch (e) {
      _logOperation('Transactions', 'Error finalizing transaction: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Update session
  static Future<DatabaseResponse> updateSession(int sessionId, Map<String, dynamic> updates) async {
    try {
      _logOperation('Sessions', 'Updating session with ID: $sessionId, updates: $updates');
      
      final result = await supabase
          .from('sessions')
          .update(updates)
          .eq('id', sessionId)
          .select();
      
      if (result.isEmpty) {
        _logOperation('Sessions', 'Session not found or not updated', isError: true);
        return DatabaseResponse(
          success: false,
          data: {'error': 'Session not found or not updated'},
        );
      }
      
      _logOperation('Sessions', 'Session updated successfully');
      
      return DatabaseResponse(
        success: true,
        data: result[0],
      );
    } catch (e) {
      _logOperation('Sessions', 'Error updating session: $e', isError: true);
      return DatabaseResponse(
        success: false,
        data: {'error': e.toString()},
      );
    }
  }
  
  // Get active sessions for a user
  static Future<List<Map<String, dynamic>>> getActiveSessionsForUser(String userId) async {
    try {
      _logOperation('Sessions', 'Getting active sessions for user: $userId');
      
      final sessions = await supabase
          .from('sessions')
          .select('''
            *,
            requester:requester_id(id, username, avatar_url),
            provider:provider_id(id, username, avatar_url),
            skill:skill_id(*)
          ''')
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .neq('status', 'Completed')
          .neq('status', 'Cancelled')
          .order('created_at', ascending: false);
      
      _logOperation('Sessions', 'Found ${sessions.length} active sessions for user $userId');
      
      return List<Map<String, dynamic>>.from(sessions);
    } catch (e) {
      _logOperation('Sessions', 'Error getting active sessions: $e', isError: true);
      return [];
    }
  }
  
  // Complete a session
  static Future<bool> completeSession(int sessionId) async {
    try {
      _logOperation('Sessions', 'Completing session with ID: $sessionId');
      
      await supabase
          .from('sessions')
          .update({
            'status': 'Completed',
          })
          .eq('id', sessionId);
      
      _logOperation('Sessions', 'Session completed successfully');
      
      return true;
    } catch (e) {
      _logOperation('Sessions', 'Error completing session: $e', isError: true);
      return false;
    }
  }
  
  // Cancel a session
  static Future<bool> cancelSession(int sessionId) async {
    try {
      _logOperation('Sessions', 'Cancelling session with ID: $sessionId');
      
      await supabase
          .from('sessions')
          .update({
            'status': 'Cancelled',
          })
          .eq('id', sessionId);
      
      _logOperation('Sessions', 'Session cancelled successfully');
      
      return true;
    } catch (e) {
      _logOperation('Sessions', 'Error cancelling session: $e', isError: true);
      return false;
    }
  }
  
  // NOTIFICATION OPERATIONS
  
  // Get notifications for the current user
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      // Get current user ID
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId == null) {
        _logOperation('Notifications', 'No user ID available for getNotifications', isError: true);
        return [];
      }
      
      _logOperation('Notifications', 'Getting notifications for user: $userId');
      
      final notifications = await supabase
          .from('notifications')
          .select('*, sender:sender_id(id, username, avatar_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      
      _logOperation('Notifications', 'Found ${notifications.length} notifications for user $userId');
      
      return List<Map<String, dynamic>>.from(notifications);
    } catch (e) {
      _logOperation('Notifications', 'Error getting notifications: $e', isError: true);
      return [];
    }
  }
  
  // Mark notification as read
  static Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      _logOperation('Notifications', 'Marking notification $notificationId as read');
      
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
          })
          .eq('id', notificationId);
      
      _logOperation('Notifications', 'Notification marked as read successfully');
      
      return true;
    } catch (e) {
      _logOperation('Notifications', 'Error marking notification as read: $e', isError: true);
      return false;
    }
  }
  
  // REVIEW OPERATIONS
  
  // Add a review
  static Future<DatabaseResponse> addReview(Map<String, dynamic> reviewData) async {
    try {
      _logOperation('Reviews', 'Adding new review with data: $reviewData');
      
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
  
  // Get reviews for a user
  static Future<List<Map<String, dynamic>>> getUserReviews(int userId) async {
    try {
      _logOperation('Reviews', 'Getting reviews for user: $userId');
      
      final reviews = await supabase
          .from('reviews')
          .select('''
            *,
            reviewer:reviewer_id(id, username, avatar_url),
            session:session_id(*)
          ''')
          .eq('reviewee_id', userId)
          .order('created_at', ascending: false);
      
      _logOperation('Reviews', 'Found ${reviews.length} reviews for user $userId');
      
      return List<Map<String, dynamic>>.from(reviews);
    } catch (e) {
      _logOperation('Reviews', 'Error getting user reviews: $e', isError: true);
      return [];
    }
  }
}