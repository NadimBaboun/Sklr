import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'database/database.dart';

class Skillinfo extends StatelessWidget {
  final int id;
  const Skillinfo({super.key, required this.id});

  Future<Map<String, dynamic>> fetchSkill(int? id) async {
    if (id == null) {
      throw Exception('Skill does not exist');
    }

    try {
      return DatabaseHelper.fetchOneSkill(id);
    } catch (error) {
      throw Exception('Failed to fetch skill: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'Skill Info',
            style: GoogleFonts.mulish(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF6296FF),
          centerTitle: true,
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: fetchSkill(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Text('Skill not found'),
              );
            } else {
              // Skill data is available
              final skill = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${skill['name']}',
                        style: GoogleFonts.mulish(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Description: ${skill['description']}',
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Category: ${skill['category']}',
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Created At: ${skill['created_at']}',
                        style: GoogleFonts.mulish(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
