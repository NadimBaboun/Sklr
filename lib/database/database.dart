import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Future<String> initializeDatabase() async {
    // Get the documents directory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDirectory.path, "Sklr.db");

    // Check if the database already exists
    if (!await File(dbPath).exists()) {
      // Copy the database from assets
      ByteData data = await rootBundle.load("assets/Sklr.db");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write the database to the documents directory
      await File(dbPath).writeAsBytes(bytes);
    }

    return dbPath;
  }

  static Future<Database> openDatabaseConnection() async {
    String dbPath = await initializeDatabase();
    return openDatabase(dbPath);
  }

  // C: create data in table
  static Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await openDatabaseConnection();
    return await db.insert(table, data);
  }

  // R: read data from table
  static Future<List<Map<String, dynamic>>> fetchAll(String table) async {
    final db = await openDatabaseConnection();
    return await db.query(table);
  }

  // R: read data from table by id
  static Future<Map<String, dynamic>?> fetchById(String table, int id) async {
    final db = await openDatabaseConnection();
    List<Map<String, dynamic>> result = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  // R: read data from table by custom query
  static Future<List<Map<String, dynamic>>> fetchByQuery(String table, String where, List<dynamic> whereArgs) async {
    final db = await openDatabaseConnection();
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  // U: update data in table by id
  static Future<int> update(String table, int id, Map<String, dynamic> data) async {
    final db = await openDatabaseConnection();
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  // U: update data in table by custom query
  static Future<int> updateByQuery(String table, String where, List<dynamic> whereArgs, Map<String, dynamic> data) async {
    final db = await openDatabaseConnection();
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  // D: delete data in table by id
  static Future<int> delete(String table, int id) async {
    final db = await openDatabaseConnection();
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // D: delete data in table by custom query
  static Future<int> deleteByQuery(String table, String where, List<dynamic> whereArgs) async {
    final db = await openDatabaseConnection();
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  //                  Message / Chat Functionallity
  /*--------------------------------------------------------------------------------------*/

  //Fetch all chats for user
  static Future<List<Map<String, dynamic>>> fetchUserChats(int userId) async {
  final db = await openDatabaseConnection();
  return await db.rawQuery('''
    SELECT chats.id AS chat_id, 
           chats.last_message, 
           chats.last_updated,
           CASE 
             WHEN chats.user1_id = ? THEN chats.user2_id 
             ELSE chats.user1_id 
           END AS other_user_id
    FROM chats
    WHERE chats.user1_id = ? OR chats.user2_id = ?
    ORDER BY chats.last_updated DESC
    ''', [userId, userId, userId]);
  }

  //Fetch All messages in a specific chat
  static Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
  final db = await openDatabaseConnection();
  return await db.query(
    'messages',
    where: 'chat_id = ?',
    whereArgs: [chatId],
    orderBy: 'timestamp ASC',
  );
  }

  //Creates or gets a chat for user
  static Future<int> getOrCreateChat(int user1Id, int user2Id) async {
  final db = await openDatabaseConnection();
  List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT * FROM chats
    WHERE (user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)
    ''', [user1Id, user2Id, user2Id, user1Id]);

  if (result.isNotEmpty) {
    return result.first['id'] as int;
  }

  return await db.insert('chats', {
    'user1_id': user1Id,
    'user2_id': user2Id,
    'last_message': null,
    'last_updated': DateTime.now().toIso8601String(),
  });
  }

  //Send message 
  static Future<void> sendMessage(int chatId, int senderId, String message) async {
  final db = await openDatabaseConnection();

  await db.insert('messages', {
    'chat_id': chatId,
    'sender_id': senderId,
    'message': message,
  });

  await db.update(
    'chats',
    {
      'last_message': message,
      'last_updated': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [chatId],
  );
  }

  //Delete chat
  static Future<int> deleteChat(int chatId) async {
  final db = await openDatabaseConnection();
  return await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
  }

  /*--------------------------------------------------------------------------------------*/
}
