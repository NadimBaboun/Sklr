import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Backend URL
const String backendUrl = 'http://localhost:3000/api';

class DatabaseHelper {
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
