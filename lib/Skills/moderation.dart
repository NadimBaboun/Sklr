import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Skills/skillInfo.dart';
import 'package:sklr/database/database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

final supabase = Supabase.instance.client;

class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key});

  @override
  _ModerationPageState createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }
  
  Future<List<Map<String, dynamic>>> _fetchReports() async {
    try {
      log('Fetching pending reports from database');
      final reports = await supabase
        .from('reports')
        .select('''
          *,
          reporter:reporter_id (id, username, avatar_url),
          skill:skill_id (
            *,
            user:user_id (id, username, avatar_url)
          )
        ''')
        .eq('status', 'Pending')
        .order('created_at', ascending: false);
      
      log('Fetched ${reports.length} reports');
      
      // Filter out reports for skills that no longer exist
      final validReports = reports.where((report) {
        return report['skill'] != null && report['skill'].isNotEmpty;
      }).toList();
      
      if (validReports.length != reports.length) {
        log('Filtered out ${reports.length - validReports.length} reports with missing skills');
        
        // Auto-resolve reports with missing skills
        for (var report in reports) {
          if (report['skill'] == null || report['skill'].isEmpty) {
            try {
              await supabase
                .from('reports')
                .update({
                  'status': 'Resolved',
                  'resolution': 'Auto-resolved - Skill no longer exists',
                  'resolved_at': DateTime.now().toIso8601String()
                })
                .eq('id', report['id']);
              
              log('Auto-resolved report ID: ${report['id']} for missing skill');
            } catch (e) {
              log('Error auto-resolving report: $e');
            }
          }
        }
      }
      
      return List<Map<String, dynamic>>.from(validReports);
    } catch (e) {
      log('Error fetching reports: $e');
      return [];
    }
  }

  Future<void> _resolveReport(int reportId, String resolution) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update the report as resolved
      await supabase
        .from('reports')
        .update({
          'status': 'Resolved',
          'resolution': resolution,
          'resolved_at': DateTime.now().toIso8601String()
        })
        .eq('id', reportId);
      
      // Reload reports
      await _fetchReports();
      
      // Show success message
      _showSnackBar('Report resolved as: $resolution');
    } catch (e) {
      _showSnackBar('Error resolving report: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _removeSkill(int skillId, int reportId) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      log('Starting skill removal process for skill ID: $skillId, report ID: $reportId');
      
      // Use the DatabaseHelper method that handles all cascading deletes
      final result = await DatabaseHelper.removeReportedSkill(reportId);
      
      if (result) {
        log('Successfully removed skill and resolved report');
        
        // Show success message
        _showSnackBar('Skill removed and report resolved');
      } else {
        log('Failed to remove skill completely, but report was resolved');
        
        _showSnackBar('Could not completely remove skill but report has been resolved', backgroundColor: Colors.orange);
      }
      
      // Reload reports
      setState(() {
        _reportsFuture = _fetchReports();
      });
    } catch (e) {
      log('Error in _removeSkill: $e');
      _showSnackBar('Error removing skill: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Moderation Panel',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _reportsFuture = _fetchReports();
              });
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _reportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final reports = snapshot.data ?? [];
                
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          'No reports to review',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final skill = report['skill'] ?? {};
                    final reporter = report['reporter'] ?? {};
                    final skillOwner = skill['user'] ?? {};
                    
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      elevation: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: skill['image_url'] != null
                                  ? NetworkImage(skill['image_url'])
                                  : null,
                              child: skill['image_url'] == null
                                  ? Text(skill['name']?.substring(0, 1) ?? 'S')
                                  : null,
                            ),
                            title: Text(
                              skill['name'] ?? 'Unknown Skill',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'By ${skillOwner['username'] ?? 'Unknown User'}',
                              style: GoogleFonts.poppins(),
                            ),
                            trailing: Text(
                              '${skill['cost'] ?? 0} Credits',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SkillInfoPage(
                                    skillId: skill['id'],
                                  ),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reported By:',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundImage: reporter['avatar_url'] != null
                                        ? NetworkImage(reporter['avatar_url'])
                                        : null,
                                    child: reporter['avatar_url'] == null
                                        ? Text(reporter['username']?.substring(0, 1) ?? 'U')
                                        : null,
                                  ),
                                  title: Text(
                                    reporter['username'] ?? 'Unknown User',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Reason:',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  report['text'] ?? 'No reason provided',
                                  style: GoogleFonts.poppins(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Reported on:',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatDate(report['created_at']),
                                  style: GoogleFonts.poppins(),
                                ),
                              ],
                            ),
                          ),
                          ButtonBar(
                            alignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle, color: Colors.white),
                                label: Text(
                                  'Keep',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: _isLoading 
                                    ? null 
                                    : () => _resolveReport(report['id'], 'Approved'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.remove_circle, color: Colors.white),
                                label: Text(
                                  'Remove',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: _isLoading 
                                    ? null 
                                    : () => _removeSkill(skill['id'], report['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
  
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // Safe method to show SnackBars
  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: backgroundColor,
        ),
      );
    } catch (e) {
      log('Error showing SnackBar: $e');
    }
  }
} 