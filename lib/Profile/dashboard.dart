import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/Skills/skillInfo.dart';

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({Key? key}) : super(key: key);

  @override
  _ModeratorDashboardState createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  late Future<List<Map<String, dynamic>>> reportsFuture;

  @override
  void initState() {
    super.initState();
    reportsFuture = DatabaseHelper.fetchReports();
  }

  void reloadReports() {
    setState(() {
      reportsFuture = DatabaseHelper.fetchReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Moderation Dashboard",
          style: GoogleFonts.mulish(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF6296FF),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error fetching reports: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reports found.'));
          } else {
            final reports = snapshot.data!;
            return ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final skillId = report['skill_id'];
               
                return FutureBuilder<Map<String, dynamic>>(
                  future: DatabaseHelper.fetchOneSkill(skillId),
                  builder: (context, skillSnapshot) {
                    if (skillSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (skillSnapshot.hasError) {
                      return Center(child: Text('Error fetching skill: ${skillSnapshot.error}'));
                    } else if (!skillSnapshot.hasData || skillSnapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    } else {
                      final skill = skillSnapshot.data!;
                      final skillName = skill['name'];
                      final skillDesc = skill['description'];

                      return Card(
                        color: Colors.grey[200],
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => Skillinfo(id: skill['id']))
                            );
                          },
                          child: ListTile(
                            title: Text(
                              skillName,
                              style: GoogleFonts.mulish(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  skillDesc,
                                  style: GoogleFonts.mulish(color: Colors.grey),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis
                                ),
                                // const SizedBox(height: 8),
                                // Text('Report Details:  $reportText'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove Listing',
                                  onPressed: () {
                                    _confirmationDialog(
                                      context: context, 
                                      title: 'Remove Listing', 
                                      content: 'Are you sure you want to remove this listing? This action is irreversible.', 
                                      onConfirm: () async {
                                        // remove listing & report
                                        final result = await DatabaseHelper.resolveReport(report['id']);
                                        if (result) {
                                          reloadReports();
                                        }
                                      }
                                    );
                                  }
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: 'Dismiss Report',
                                  onPressed: () {
                                    _confirmationDialog(
                                      context: context, 
                                      title: 'Dismiss report', 
                                      content: 'Are you sure you want to dismiss this report? This action is irreversible.', 
                                      onConfirm: () async {
                                        // dismiss report
                                        final result = await DatabaseHelper.removeReport(report['id']);
                                        if (result) {
                                          reloadReports();
                                        }
                                      }
                                    );
                                  },
                                )
                              ],
                            ),
                          )
                        )
                      );
                    }
                  }
                );
              }
            );
          }
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          reloadReports();
        },
        tooltip: 'Reload Reports',
        backgroundColor: const Color(0xFF6296FF),
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh_outlined)
      ),
    );
  }

  Future<void> _confirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              child: const Text('Confirm'),
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
