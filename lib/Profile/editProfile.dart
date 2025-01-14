import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? usernameError;
  String? emailError;
  String? bioError;

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF6296FF),
        title: Text(
          "Edit Profile",
          style: GoogleFonts.mulish(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 40.0 : 20.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),

              // Bio
              TextField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(
                    color: Colors.black, // Ändra färgen på etiketten
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey), // Default underline color
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue), // Color when focused
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (bioError != null)
                Text(
                  bioError!,
                  style: GoogleFonts.mulish(
                    color: Colors.red,
                  )
                ),
              const SizedBox(height: 32),
              // Username
              // TextField(
              //   controller: _usernameController,
              //   decoration: InputDecoration(
              //     labelText: 'Username',
              //     labelStyle: TextStyle(
              //       color: Colors.black, // Ändra färgen på etiketten
              //     ),
              //     enabledBorder: UnderlineInputBorder(
              //       borderSide: BorderSide(color: Colors.grey), // Default underline color
              //     ),
              //     focusedBorder: UnderlineInputBorder(
              //       borderSide: BorderSide(color: Colors.blue), // Color when focused
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 8),
              // if (usernameError != null)
              //   Text(
              //     usernameError!,
              //     style: GoogleFonts.mulish(
              //       color: Colors.red,
              //     )
              //   ),
              // const SizedBox(height: 32),
              // // Email
              // TextField(
              //   controller: _emailController,
              //   decoration: InputDecoration(
              //     labelText: 'Email',
              //     labelStyle: TextStyle(
              //       color: Colors.black, // Ändra färgen på etiketten
              //     ),
              //     enabledBorder: UnderlineInputBorder(
              //       borderSide: BorderSide(color: Colors.grey), // Default underline color
              //     ),
              //     focusedBorder: UnderlineInputBorder(
              //       borderSide: BorderSide(color: Colors.blue), // Color when focused
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 8),
              // if (emailError != null)
              //   Text(
              //     emailError!,
              //     style: GoogleFonts.mulish(
              //       color: Colors.red,
              //     )
              //   ),
              const SizedBox(height: 32),
              // Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final newBio = _bioController.text;
                    final Map<String, dynamic> update = { 'bio': newBio };
                    final userId = await UserIdStorage.getLoggedInUserId();
                    final result = await DatabaseHelper.patchUser(userId!, update);
                    if (result.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bio was updated')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update bio')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6296FF),
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 50.0 : 30.0,
                      vertical: 15.0,
                    ),
                  ),
                  child: Text('Submit',
                  style: GoogleFonts.mulish(
                    color: Colors.white,
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//responsive check done 