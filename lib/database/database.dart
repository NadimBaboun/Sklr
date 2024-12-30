import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

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
}
