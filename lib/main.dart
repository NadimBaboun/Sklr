import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/Home/home.dart';
import 'package:sklr/Util/startpage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  
  // test database connection
  DatabaseHelper.testConnection().then((data) => {
    log('testConnection(): $data')
  });

  // look for rememberMe in SharedPrefs.
  bool? rememberMe = await UserIdStorage.getRememberMe();
  // log('rememberMe: $rememberMe');
  // rememberMe is enabled
  if (rememberMe != null && rememberMe) {
    // look for userId in SharedPrefs.
    int? userId = await UserIdStorage.getLoggedInUserId();
    // log('userId: $userId');
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