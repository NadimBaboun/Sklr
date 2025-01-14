import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/Home/home.dart';
import 'package:sklr/Util/startpage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized

  // Test database connection
  DatabaseHelper.testConnection().then((data) => {
        log('testConnection(): $data')
      });

  // Look for rememberMe in SharedPrefs.
  bool? rememberMe = await UserIdStorage.getRememberMe();
  // log('rememberMe: $rememberMe');
  // RememberMe is enabled
  if (rememberMe != null && rememberMe) {
    // Look for userId in SharedPrefs.
    int? userId = await UserIdStorage.getLoggedInUserId();
    // log('userId: $userId');
    // userId is set
    if (userId != null && userId > 0) {
      runApp(MyApp(home: const HomePage()));
    } else {
      runApp(MyApp(home: const StartPage()));
    }
  } else {
    runApp(MyApp(home: const StartPage()));
  }
}

class MyApp extends StatelessWidget {
  final Widget home;

  const MyApp({Key? key, required this.home}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove the debug banner
      home: home,
    );
  }
}