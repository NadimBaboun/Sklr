import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Response {
  final bool success;
  final String message;

  Response({
    required this.success,
    required this.message,
  });
}

class LoginResponse {
  final bool success;
  final String message;
  final int userId;

  LoginResponse(
      {required this.success, required this.message, this.userId = -1});
}

class DatabaseResponse {
  final bool success;
  final Map<String, dynamic> data;

  DatabaseResponse({required this.success, required this.data});
}

class DatabaseHelper {
  static final String backendUrl = _initBackendUrl();

  static String _initBackendUrl() {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  // test backend server connection
  static Future<String> testConnection() async {
    final url = Uri.parse(backendUrl);

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body)['status'];
      } else {
        return 'failed connection (${response.statusCode})';
      }
    } catch (err) {
      return 'failed connection: $err';
    }
  }

  // auth: Register
  static Future<LoginResponse> registerUser(
      String username, String email, String password) async {
    final url = Uri.parse('$backendUrl/register');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body)['user'];

      if (response.statusCode == 201) {
        // resource created @ server
        return LoginResponse(
          success: true,
          message: 'User registered successfully',
          userId: data['id'],
        );
      } else if (response.statusCode == 409) {
        // user already exists
        return LoginResponse(
          success: false,
          message: 'User already exists, did you mean to log in?',
        );
      } else {
        // other errors
        return LoginResponse(
          success: false,
          message: data['error'],
        );
      }
    } catch (err) {
      return LoginResponse(
        success: false,
        message: err.toString(),
      );
    }
  }

  // auth: Login, fetch user id of user from email + password
  static Future<LoginResponse> fetchUserId(
      String email, String password) async {
    final url = Uri.parse('$backendUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return LoginResponse(
          success: true,
          message: 'Login successful',
          userId: data['user_id'],
        );
      } else {
        return LoginResponse(
          success: false,
          message: data['error'],
        );
      }
    } catch (err) {
      return LoginResponse(
        success: false,
        message: err.toString(),
      );
    }
  }

  // fetch user from userId
  static Future<DatabaseResponse> fetchUserFromId(int userId) async {
    final url = Uri.parse('$backendUrl/users/$userId');

    try {
      final response = await http.get(url);

      final data = json.decode(response.body)['user'];

      if (response.statusCode == 200) {
        return DatabaseResponse(
          success: true,
          data: data,
        );
      } else {
        return DatabaseResponse(
          success: false,
          data: data['error'],
        );
      }
    } catch (err) {
      return DatabaseResponse(success: false, data: {'error': err.toString()});
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

    final url = Uri.parse('$backendUrl/users/$userId');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(fields),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return DatabaseResponse(
          success: true,
          data: data['user'],
        );
      } else {
        return DatabaseResponse(
          success: false,
          data: data['error'],
        );
      }
    } catch (err) {
      return DatabaseResponse(
        success: false,
        data: {'error': err.toString()},
      );
    }
  }

  // award user 1 credit upon verification of phone number
  static Future<bool> awardUser(int userId) async {
    final url = Uri.parse('$backendUrl/users/$userId/award');

    try {
      final response = await http.post(url);

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (err) {
      return false;
    }
  }

  //fetch one skill from id
  static Future<Map<String, dynamic>?> fetchOneSkill(int id) async {
    final response = await http.get(Uri.parse('$backendUrl/skills/$id'));

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return responseData['skills'] as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load skill');
    }
  }

  //fetching the skills of a user
  static Future<List<Map<String, dynamic>>> fetchSkills(int userId) async {
    final response =
        await http.get(Uri.parse('$backendUrl/skills/user/$userId'));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load skills');
    }
  }

  //insert skill into database
  static Future<Response> insertSkill(
      int? userId, String name, String description, String? category) async {
    final url = Uri.parse('$backendUrl/skills');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'description': description,
          'created_at': DateTime.now().toIso8601String(),
          'category': category,
        }),
      );

      if (response.statusCode == 201) {
        // skill added
        return Response(
          success: true,
          message: 'Skill added successfully',
        );
      } else if (response.statusCode == 409) {
        return Response(
          success: false,
          message: 'Skill could not be added',
        );
      } else {
        throw Exception('Failed to insert skill');
      }
    } catch (err) {
      return Response(
        success: false,
        message: err.toString(),
      );
    }
  }

  //delete skill from database
  // ignore: non_constant_identifier_names
  static Future<Response> deleteSkill(String name, int? user_id) async {
    final url = Uri.parse('$backendUrl/skills/$name/$user_id');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // skill deleted successfully
        return Response(
          success: true,
          message: 'Skill deleted successfully',
        );
      } else if (response.statusCode == 404) {
        return Response(
          success: false,
          message: 'Skill not found',
        );
      } else {
        throw Exception('Failed to delete skill');
      }
    } catch (err) {
      return Response(
        success: false,
        message: err.toString(),
      );
    }
  }

  //check if name exists in skill table
  static Future<bool> checkSkillName(String name, int? user_id) async {
    final url = Uri.parse('$backendUrl/skills/$name/$user_id');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // the skill exists
        return true;
      } else if (response.statusCode == 404) {
        //the skill does not exist
        return false;
      } else {
        throw Exception('Failed to check skill existence');
      }
    } catch (err) {
      print('Error: $err');
      return false;
    }
  }

  //                  Message / Chat Functionallity
  /*--------------------------------------------------------------------------------------*/

  //FetchChats for user
  static Future<List<Map<String, dynamic>>> fetchChats(int userId) async {
    final response = await http.get(Uri.parse('$backendUrl/chat/user/$userId'));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load chats');
    }
  }

  //Fetch Messages in a chat
  static Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
    final response =
        await http.get(Uri.parse('$backendUrl/chat/$chatId/messages'));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load messages');
    }
  }

  static Future<void> sendMessage(
      int chatId, int senderId, String message) async {
    final response = await http.post(
      Uri.parse('$backendUrl/chat/$chatId/message'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'senderId': senderId, 'message': message}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send message');
    }
  }

  static Future<int> getOrCreateChat(int user1Id, int user2Id) async {
    final response = await http.post(
      Uri.parse('$backendUrl/chat/get-or-create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user1Id': user1Id, 'user2Id': user2Id}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['chat_id'];
    } else {
      throw Exception('Failed to create or fetch chat');
    }
  }

  /*--------------------------------------------------------------------------------------*/
}
