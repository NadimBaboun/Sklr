import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/homepage.dart';
import 'package:sklr/startpage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  
  // test database connection
  DatabaseHelper.testConnection().then((data) => {
    log('testConnection(): $data')
  });

  // look for rememberMe in SharedPrefs.
  bool? rememberMe = await UserIdStorage.getRememberMe();
  // rememberMe is enabled
  if (rememberMe != null && rememberMe) {
    // look for userId in SharedPrefs.
    int? userId = await UserIdStorage.getLoggedInUserId();
    log('userId: $userId');
    // userId is set
    if (userId != null && userId > 0) {
      runApp(const HomePage());
    }
    else {
      runApp(const StartPage());
    }
  }
  else {
    runApp(const StartPage());
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
