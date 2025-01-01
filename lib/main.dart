import 'package:flutter/material.dart';
import 'package:sklr/startpage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await DatabaseHelper.initializeDatabase(); // Initialize database
  runApp(const StartPage());
}

class DatabaseHelper {
  static Future<String> initializeDatabase() async {
    // Get the app's documents directory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDirectory.path, "Sklr.db");

    // Check if database already exists
    if (!await File(dbPath).exists()) {
      // Copy database from assets to the device's storage
      ByteData data = await rootBundle.load("assets/Sklr.db");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
