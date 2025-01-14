import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Profile.dart';
import 'package:sklr/chatPage.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'database/database.dart';
import 'userpage.dart';

class Skillinfo extends StatelessWidget {
  final int id;
  Skillinfo({super.key, required this.id});
  String userName = '';

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

  Future<Map<String, dynamic>> fetchUser(int id) async {
    final response = await DatabaseHelper.fetchUserFromId(id);
    if (response.success) {
      return response.data;
    } else {
      throw Exception('Failed to fetch user');
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
          builder: (context, skillSnapshot) {
            if (skillSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (skillSnapshot.hasError) {
              return Center(
                child: Text('Error: ${skillSnapshot.error}'),
              );
            } else if (!skillSnapshot.hasData || skillSnapshot.data == null) {
              return Center(
                child: Text('Skill not found'),
              );
            } else {
              final skill = skillSnapshot.data!;
              return FutureBuilder<Map<String, dynamic>>(
                future: fetchUser(skill['user_id']),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (userSnapshot.hasError) {
                    return Center(
                      child: Text('Error: ${userSnapshot.error}'),
                    );
                  } else if (!userSnapshot.hasData ||
                      userSnapshot.data == null) {
                    return Center(
                      child: Text('User not found'),
                    );
                  } else {
                    final user = userSnapshot.data!;
                    return Center(
                      // Centering all content
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Centered horizontally
                          mainAxisAlignment:
                              MainAxisAlignment.start, // Centered vertically
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              '${skill['name']}',
                              style: GoogleFonts.mulish(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: () async {
                                final loggedInUserId = await UserIdStorage.getLoggedInUserId();
                                if(skill['user_id'] == loggedInUserId) {
                                  Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProfilePage(),
                                  ),
                                  );
                                }else{

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        UserPage(userId: skill['user_id']),
                                  ),
                                );
                                }
                              },
                              child: Text(
                                'Created by: ${user['username']}',
                                style: GoogleFonts.mulish(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6296FF),
                                 
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            Text(
                              '${skill['description']}',
                              style: GoogleFonts.mulish(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Category: ${skill['category']}',
                              style: GoogleFonts.mulish(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${skill['created_at'].toString().substring(0, 10)}',
                              style: GoogleFonts.mulish(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // start chat button, disable when viewing own listing
                            FutureBuilder(
                              future: UserIdStorage.getLoggedInUserId(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final loggedInUserId = snapshot.data;
                                if (loggedInUserId == skill['user_id']) {
                                  return Text(
                                    'This is your own skill!',
                                    style: GoogleFonts.mulish(
                                      color: Colors.grey
                                    )
                                  );
                                }

                                return ElevatedButton.icon( 
                                  onPressed: () async {
                                    // fetch logged in user
                                    final self = await UserIdStorage.getLoggedInUserId();
                                    // create session between users
                                    final session = await DatabaseHelper.createSession(self!, skill['id']);
                                    final result = await DatabaseHelper.getOrCreateChat(self, skill['user_id'], session.data['data']['id']);
                                    Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => ChatPage(chatId: result, loggedInUserId: self, otherUsername: user['username'])));
                                  },
                                  icon: const Icon(Icons.message, color: Colors.white),
                                  label: Text('Start Conversation', style: GoogleFonts.mulish(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)
                                    )
                                  )
                                );
                              }
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder(
                              future: UserIdStorage.getLoggedInUserId(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final loggedInUserId = snapshot.data!;
                                if (loggedInUserId == skill['user_id']) {
                                  return const SizedBox.shrink();
                                }

                                return ElevatedButton.icon(
                                  onPressed: () {
                                    // create report
                                    _confirmReport(context, skill['id']);
                                  },
                                  icon: const Icon(Icons.report_outlined, color: Colors.white),
                                  label: Text('Report', style: GoogleFonts.mulish(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)
                                    )
                                  )
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmReport(BuildContext context, int skillId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Report'),
          content: const Text('Are you sure you want to report this skill?'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await DatabaseHelper.createReport(skillId);
              },
              child: const Text('Report'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ]
        );
      }
    );
  }
}
