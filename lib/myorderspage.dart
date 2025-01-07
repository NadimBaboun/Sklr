import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/service-categories.dart';
import 'package:sklr/Profile.dart';
import 'homepage.dart';
import 'chatsHomePage.dart';
import 'database/database.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<int?> getLoggedInUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('loggedInUserId');
}

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  MyOrdersPageState createState() => MyOrdersPageState();
}

class MyOrdersPageState extends State<MyOrdersPage> {
  Future<List<Map<String, dynamic>>> fetchUserSkills() async {
    //final int? userId = await getLoggedInUserId();

    /*if (userId == null) {
      throw Exception('No user is logged in');
    }

    return await DatabaseHelper.fetchByQuery(
      'skills',
      'user_id = ?',
      [userId],
    );*/

    //mocked data for testing

    return [
      {
        'skill_name': 'Flutter Development',
        'skill_description': 'Building mobile apps with Flutter.',
        'created_at': '2025-01-01',
      },
      {
        'skill_name': 'Painting with watercolors',
        'skill_description': 'Get useful help when painting with watercolors.',
        'created_at': '2024-12-01',
      },
      {
        'skill_name': 'UI/UX Design',
        'skill_description': 'Designing user interfaces and experiences.',
        'created_at': '2023-11-20',
      },
      {
        'skill_name': 'Dog Training',
        'skill_description': 'Get help with training you dog.',
        'created_at': '2024-11-04',
      },
      {
        'skill_name': 'Spanish for beginners',
        'skill_description':
            'Spanish help for those who are new to the language.',
        'created_at': '2024-07-01',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Orders",
          style: GoogleFonts.mulish(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF6296FF),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchUserSkills(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No skills found'));
          }

          final skills = snapshot.data!;

          return ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];
              return ListTile(
                title: Text(skill['skill_name'] ?? 'No Skill Name'),
                subtitle: Text(skill['skill_description'] ?? 'No Description'),
                trailing: Text(skill['created_at'] ?? ''),
                onTap: () {
                  // go to the skill page
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 2.0,
          ),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => ChatsHomePage(loggedInUserId: 1)),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MyOrdersPage()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
              break;
          }
        },
        selectedItemColor: const Color(0xFF6296FF),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
