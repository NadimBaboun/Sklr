import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<int?> getLoggedInUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('loggedInUserId');
}

class AddSkillPage extends StatefulWidget {
  const AddSkillPage({super.key});
  @override
  AddSkillPageState createState() => AddSkillPageState();
}

class AddSkillPageState extends State<AddSkillPage> {
  String skillname = '';
  String skilldescription = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            "Add a skill to share with someone!",
            style: GoogleFonts.mulish(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF6296FF),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) {
                  setState(() {
                    skillname = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Enter title for skill",
                  prefixIcon: const Icon(Icons.title),
                  fillColor: const Color.fromARGB(125, 207, 235, 252),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              TextField(
                onChanged: (value) {
                  setState(() {
                    skilldescription = value;
                  });
                },
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Enter skill description",
                  prefixIcon: const Icon(Icons.description),
                  fillColor: const Color.fromARGB(125, 207, 235, 252),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  //create the skill in database.
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6296FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Create",
                  style: GoogleFonts.mulish(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.mulish(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
