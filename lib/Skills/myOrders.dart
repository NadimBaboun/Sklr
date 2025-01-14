import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/Skills/skillInfo.dart';
import '../database/database.dart';
import '../Util/navigationbar-bar.dart';
import 'addSkill.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  MyOrdersPageState createState() => MyOrdersPageState();
}

class MyOrdersPageState extends State<MyOrdersPage> {
  int? loggedInUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await UserIdStorage.getLoggedInUserId();
    setState(() {
      loggedInUserId = userId;
    });
  }

  Future<List<Map<String, dynamic>>> fetchUserSkills(int? userId) async {
    if (userId == null) {
      throw Exception('No user is logged in');
    }

    try {
      return await DatabaseHelper.fetchSkills(userId);
    } catch (error) {
      throw Exception('Failed to fetch user skills: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "My Skill Listings",
          style: GoogleFonts.mulish(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF6296FF),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchUserSkills(loggedInUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have not uploaded any skills!',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final skills = snapshot.data!;
          return ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];

              return Column(
                children: [
                  Dismissible(
                    key: Key(skill['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) {
                      DatabaseHelper.deleteSkill(skill['name'], loggedInUserId);
                      skills.removeAt(index);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${skill['name']} deleted')),
                      );
                    },
                    child: ListTile(
                      title: Text(skill['name'] ?? 'No Skill Name'),
                      subtitle: Text(skill['description'] ?? 'No Description'),
                      trailing: Text(skill['created_at'].toString().substring(0, 10)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Skillinfo(id: skill['id']),
                          ),
                        );
                      },
                    ),
                  ),
                  if (index != skills.length - 1) const Divider(height: 1),
                ],
              );
            },
          );
          
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddSkillPage()),
                      );
        },
        tooltip: 'Increment',
        backgroundColor: const Color(0xFF6296FF),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar:
          CustomBottomNavigationBar(currentIndex: 2),
    );
  }
}
