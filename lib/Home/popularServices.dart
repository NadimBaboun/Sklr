import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PopularServices extends StatefulWidget {
  const PopularServices({Key? key}) : super(key: key);
  
  @override
  _PopularServicesState createState() => _PopularServicesState();
}

class _PopularServicesState extends State<PopularServices> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Popular Services',
          style: GoogleFonts.poppins(
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Discover Popular Services',
                style: GoogleFonts.poppins(
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // Service listings would go here
            // This is a placeholder for the actual service listings
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10, // Placeholder count
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF2196F3),
                      child: Icon(Icons.work, color: Colors.white),
                    ),
                    title: Text(
                      'Service ${index + 1}',
                      style: GoogleFonts.poppins(
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      'Service description goes here',
                      style: GoogleFonts.poppins(),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to service details
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}