import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'register.dart';
import 'loginpage.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Getting screen width and height
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Container(
              color: Colors.white,
            ),
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.1), // 10% of screen height
                    Text(
                      'Sklr',
                      style: GoogleFonts.averiaSansLibre(
                        textStyle: TextStyle(
                          color: Color(0xFF6296FF),
                          fontSize: screenWidth * 0.2, // 20% of screen width
                        ),
                      ),
                    ),
                    Text(
                      'Share. Learn. Repeat',
                      style: GoogleFonts.mulish(
                        textStyle: TextStyle(
                          color: Colors.black,
                          fontSize: screenWidth * 0.04, // 4% of screen width
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/images/skillerlogo.png',
                      height: screenWidth * 0.6, // 60% of screen width
                      width: screenWidth * 0.6,  // 60% of screen width
                      fit: BoxFit.cover,
                    ),
                    Text(
                      'Login with...',
                      style: GoogleFonts.mulish(
                        textStyle: TextStyle(
                          color: Colors.black,
                          fontSize: screenWidth * 0.05, // 5% of screen width
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02), // 2% of screen height
                    Builder(
                      builder: (BuildContext context) {
                        return SizedBox(
                          width: screenWidth * 0.7, // 70% of screen width
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => LoginPage()),
                              );
                            },
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Colors.white),
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.blueGrey),
                                ),
                              ),
                            ),
                            child: Text(
                              'Email',
                              style: GoogleFonts.mulish(
                                textStyle: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.04, // 4% of screen width
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: screenHeight * 0.02), // 2% of screen height
                    Builder(
                      builder: (BuildContext context) {
                        return SizedBox(
                          width: screenWidth * 0.7, // 70% of screen width
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              //go to google login page!
                            },
                            style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(Colors.white),
                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.blueGrey),
                                ))),
                            child: Text(
                              'Google',
                              style: GoogleFonts.mulish(
                                textStyle: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.04, // 4% of screen width
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: screenHeight * 0.02), // 2% of screen height
                    Builder(
                      builder: (BuildContext context) {
                        return SizedBox(
                          width: screenWidth * 0.7, // 70% of screen width
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              //go to apple login page!
                            },
                            style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(Colors.black),
                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.black),
                                ))),
                            child: Text(
                              'Apple',
                              style: GoogleFonts.mulish(
                                textStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04, // 4% of screen width
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: screenHeight * 0.02), // 2% of screen height
                    Builder(
                      builder: (context) {
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => Register()),
                            );
                          },
                          child: Text(
                            'Create an account',
                            style: GoogleFonts.mulish(
                              textStyle: TextStyle(
                                color: Color(0xFF6296FF),
                                fontSize: screenWidth * 0.05, // 5% of screen width
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//responsive check done 