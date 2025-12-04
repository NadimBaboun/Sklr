import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/Skills/skill_info.dart';

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({Key? key}) : super(key: key);

  @override
  _ModeratorDashboardState createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> reportsFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    reportsFuture = DatabaseHelper.fetchReports();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> reloadReports() async {
    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      final reports = await DatabaseHelper.fetchReports();
      
      if (mounted) {
        setState(() {
          reportsFuture = Future.value(reports);
          isLoading = false;
        });
      }
      
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      print('Error reloading reports: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          // Set to empty list on error rather than keeping old state
          reportsFuture = Future.value([]);
        });
        
        _showSnackBar(context, 'Error loading reports: $e', backgroundColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6296FF), Color(0xFF4A7BFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6296FF).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Moderation',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                          ),
                          onPressed: isLoading ? null : reloadReports,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review and manage reported content',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading reports...',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Error fetching reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_outline, size: 48, color: Colors.green[400]),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'All Clear!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reports need attention',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          } else {
            final reports = snapshot.data!;
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final skill = report['skill'] ?? {};
                  final reporter = report['reporter'] ?? {};
                  
                  if (skill == null || skill.isEmpty) {
                    return const SizedBox.shrink(); // Skip if skill is missing
                  }
                  
                  final skillName = skill['name'] ?? 'Unknown Skill';
                  final skillDesc = skill['description'] ?? 'No description available';
                  final skillOwner = skill['user'] ?? {};

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Skillinfo(id: skill['id']))
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6296FF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.flag_rounded,
                                      color: Color(0xFF6296FF),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          skillName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Reported Content',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.red[400],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'by ${reporter['username'] ?? 'Unknown User'}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (skillOwner != null && skillOwner.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Created by: ${skillOwner['username'] ?? 'Unknown User'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              Text(
                                skillDesc,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  height: 1.6,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (report['text'] != null && report['text'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Report reason:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        report['text'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: Text(
                                        'Dismiss',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      onPressed: () {
                                        _confirmationDialog(
                                          context: context,
                                          title: 'Dismiss Report',
                                          content: 'Are you sure you want to dismiss this report? This action is irreversible.',
                                          onConfirm: () async {
                                            final result = await DatabaseHelper.removeReport(report['id']);
                                            if (result) {
                                              reloadReports();
                                            }
                                          },
                                          confirmText: 'Dismiss',
                                          confirmColor: Colors.green[600]!,
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.green[600],
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(
                                        'Remove',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      onPressed: () {
                                        _confirmationDialog(
                                          context: context,
                                          title: 'Remove Listing',
                                          content: 'Are you sure you want to remove this listing? This action is irreversible.',
                                          onConfirm: () async {
                                            // Show a loading indicator
                                            _showLoadingSnackBar(context, 'Removing skill...');
                                            
                                            final result = await DatabaseHelper.removeReportedSkill(report['id']);
                                            
                                            // Dismiss the loading indicator
                                            _hideSnackBar(context);
                                            
                                            if (result) {
                                              _showSnackBar(context, 'Skill successfully removed', backgroundColor: Colors.green);
                                              reloadReports();
                                            } else {
                                              // If deletion fails, just mark as resolved
                                              await DatabaseHelper.removeReport(report['id']);
                                              _showSnackBar(context, 'Could not delete skill but report has been resolved', backgroundColor: Colors.orange);
                                              reloadReports();
                                            }
                                          },
                                          confirmText: 'Remove',
                                          confirmColor: Colors.red[600]!,
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red[600],
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    required String confirmText,
    required Color confirmColor,
  }) async {
    ScaffoldMessenger.of(context);
    
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: confirmColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    confirmText == 'Remove' ? Icons.delete_outline : Icons.check_circle_outline,
                    color: confirmColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onConfirm();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Safe helper to show SnackBar messages
  void _showSnackBar(BuildContext context, String message, {Color? backgroundColor, Duration? duration}) {
    try {
      // Store the scaffoldMessenger reference first
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: backgroundColor,
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Error showing SnackBar: $e');
    }
  }
  
  void _showLoadingSnackBar(BuildContext context, String message) {
    try {
      // Store the scaffoldMessenger reference first
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          duration: const Duration(seconds: 60),
          backgroundColor: Colors.blue[600],
        ),
      );
    } catch (e) {
      print('Error showing loading SnackBar: $e');
    }
  }
  
  void _hideSnackBar(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      print('Error hiding SnackBar: $e');
    }
  }
}