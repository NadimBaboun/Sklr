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

class MyOrdersPageState extends State<MyOrdersPage> with SingleTickerProviderStateMixin {
  int? loggedInUserId;
  List<Map<String, dynamic>>? skills;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _loadUserId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final userId = await UserIdStorage.getLoggedInUserId();
    setState(() {
      loggedInUserId = userId;
    });
    if (userId != null) {
      _loadSkills(userId);
    }
  }

  Future<void> _loadSkills(int userId) async {
    try {
      final userSkills = await DatabaseHelper.fetchSkills(userId);
      setState(() {
        skills = userSkills;
      });
      _animationController.forward();
    } catch (error) {
      debugPrint('Error loading skills: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "My Skills",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6296FF)),
            onPressed: () {
              if (loggedInUserId != null) {
                _loadSkills(loggedInUserId!);
              }
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(isLargeScreen),
      ),
      floatingActionButton: skills?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddSkillPage()),
                );
                if (loggedInUserId != null) {
                  _loadSkills(loggedInUserId!);
                }
              },
              backgroundColor: const Color(0xFF6296FF),
              icon: const Icon(Icons.add),
              label: Text(
                'Add Skill',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            )
          : null,
      bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 2),
    );
  }

  Widget _buildBody(bool isLargeScreen) {
    if (loggedInUserId == null) {
      return _buildLoadingState();
    }

    if (skills == null) {
      return _buildLoadingState();
    }

    if (skills!.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 32 : 20,
          vertical: 24,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLargeScreen ? 3 : 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: isLargeScreen ? 24 : 16,
          mainAxisSpacing: isLargeScreen ? 24 : 16,
        ),
        itemCount: skills!.length,
        itemBuilder: (context, index) => _buildSkillCard(skills![index]),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF6296FF),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your skills...',
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6296FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lightbulb_outline,
                size: 48,
                color: const Color(0xFF6296FF),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Share Your Skills',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start sharing your expertise with the community by creating your first skill listing',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddSkillPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6296FF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Create First Skill',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill) {
    return Dismissible(
      key: Key(skill['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 32,
        ),
      ),
      onDismissed: (direction) async {
        await DatabaseHelper.deleteSkill(skill['name'], loggedInUserId);
        setState(() {
          skills!.remove(skill);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skill deleted',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Skillinfo(id: skill['id']),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6296FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    skill['category'] ?? 'Uncategorized',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6296FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  skill['name'] ?? 'Untitled Skill',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    skill['description'] ?? 'No description provided',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    overflow: TextOverflow.fade,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      skill['created_at'].toString().substring(0, 10),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black45,
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
  }
}
