import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PrivacyPolicyPage(),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // This will handle the back button
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Background color for the page
            Container(
              color: Colors.white,
              width: double.infinity,
              height: 1000, // This is for scrolling, you can adjust this
            ),
            // Privacy Policy title
            Positioned(
              left: 87,
              top: 65,
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.27, // line height equivalent to 28px
                ),
              ),
            ),
            // First section - Types of data we collect
            Positioned(
              left: 24,
              top: 125,
              child: Text(
                '1. Types of data we collect',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Positioned(
              left: 24,
              top: 155,
              right: 24,
              child: Text(
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Colors.black,
                  height: 1.14, // line height equivalent to 16px
                  letterSpacing: 0.25,
                ),
              ),
            ),
            // Second section - Use of your personal data
            Positioned(
              left: 24,
              top: 341,
              child: Text(
                '2. Use of your personal data',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            // Third section - Disclosure of your personal data
            Positioned(
              left: 24,
              top: 517,
              child: Text(
                '3. Disclosure of your personal data',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            // Arrow (Vector) Icon on the left side
            Positioned(
              left: 24,
              top: 69,
              child: Icon(
                Icons.arrow_left,
                size: 24,
                color: Colors.black,
              ),
            ),
            // Background section (Vector with background color)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                color: Colors.black,
                margin: EdgeInsets.symmetric(horizontal: 24, vertical: 69),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
