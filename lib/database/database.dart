import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginResponse {
  final bool success;
  final String message;
  final int userId;

  LoginResponse({required this.success, required this.message, this.userId = -1});
}

class DatabaseResponse {
  final bool success;
  final Map<String, dynamic> data;

  DatabaseResponse({required this.success, required this.data});
}

class DatabaseHelper {
  static final String backendUrl = _initBackendUrl();

  static String _initBackendUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }
    else if (Platform.isIOS) {
      return 'http://127.0.0.1:3000/api';
    }
    else {
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

  // auth: Login, fetch user id of user from email + password
  static Future<LoginResponse> fetchUserId(String email, String password) async {
    final url = Uri.parse('${backendUrl}/login');

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
      }
      else {
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
      }
      else {
        return DatabaseResponse(
          success: false,
          data: data['error'],
        );
      }
    } catch (err) {
      return DatabaseResponse(
        success: false, 
        data: {
          'error': err.toString()
        }
      );
    }
  }

  //fetching the skills of a user
  static Future<List<Map<String,dynamic>>> fetchSkills(int userId)async {
    final response = await http.get(Uri.parse('$backendUrl/skills/user/$userId'));

    if(response.statusCode == 200){
      return List<Map<String,dynamic>>.from(json.decode(response.body));
    }
    else{
      throw Exception('Failed to load skills');
    }
  }



  //                  Message / Chat Functionallity
  /*--------------------------------------------------------------------------------------*/

  //FetchChats for user
  static Future<List<Map<String,dynamic>>> fetchChats(int userId) async{
  final response = await http.get(Uri.parse('$backendUrl/chat/user/$userId'));

  if(response.statusCode == 200){
    return List<Map<String,dynamic>>.from(json.decode(response.body));
  }
  else{
    throw Exception('Failed to load chats');
    }
  }

  //Fetch Messages in a chat
  static Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async{
    final response = await http.get(Uri.parse('$backendUrl/chat/$chatId/messages'));

    if(response.statusCode == 200){
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    else{
      throw Exception('Failed to load messages');
    }
  }

  static Future<void> sendMessage(int chatId, int senderId, String message) async {
    final response = await http.post(Uri.parse('$backendUrl/chat/$chatId/message'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'senderId': senderId, 'message': message}),
    );

    if(response.statusCode != 200){
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
