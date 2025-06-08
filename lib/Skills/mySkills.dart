import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Chat/chatsHome.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MySkills extends StatefulWidget {
  const MySkills({super.key});

  @override
  _MySkillsState createState() => _MySkillsState();
}

class _MySkillsState extends State<MySkills> with TickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> skillsFuture;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool isLoading = false;
  int? userId;
  String? username;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final currentUserId = await UserIdStorage.getLoggedInUserId();
    if (currentUserId != null) {
      final user = await DatabaseHelper.fetchUserFromId(currentUserId);
      if (user.success && mounted) {
        setState(() {
          userId = currentUserId;
          username = user.data['username'];
          skillsFuture = DatabaseHelper.fetchSkills(userId);
        });
      }
    }
  }

  Future<void> _refreshSkills() async {
    setState(() {
      skillsFuture = DatabaseHelper.fetchSkills(userId);
    });
  }
  
  void _showAddSkillDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    String? selectedCategory;
    List<String> categories = [];
    
    // Fetch categories
    DatabaseHelper.fetchCategories().then((cats) {
      if (mounted) {
        setState(() {
          categories = cats.map((cat) => cat['name'] as String).toList();
          if (categories.isNotEmpty) {
            selectedCategory = categories.first;
          }
        });
      }
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2196F3),
                              Color(0xFF1976D2),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add New Skill',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: nameController,
                        label: 'Skill Name',
                        icon: Icons.star_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: descriptionController,
                        label: 'Description',
                        icon: Icons.description_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: costController,
                        label: 'Cost (credits)',
                        icon: Icons.account_balance_wallet_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withOpacity(0.2),
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: GoogleFonts.poppins(
                              color: const Color(0xFF2196F3),
                            ),
                            prefixIcon: const Icon(
                              Icons.category_rounded,
                              color: Color(0xFF2196F3),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          items: categories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(
                                category,
                                style: GoogleFonts.poppins(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedCategory = newValue;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _addSkill(
                                nameController,
                                descriptionController,
                                costController,
                                selectedCategory,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Add Skill',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
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
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: const Color(0xFF1A1D29),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: const Color(0xFF2196F3),
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF2196F3),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _addSkill(
    TextEditingController nameController,
    TextEditingController descriptionController,
    TextEditingController costController,
    String? selectedCategory,
  ) async {
    if (nameController.text.isEmpty || 
        descriptionController.text.isEmpty || 
        costController.text.isEmpty || 
        selectedCategory == null) {
      _showSnackBar('Please fill all fields', isError: true);
      return;
    }
    
    final cost = double.tryParse(costController.text);
    if (cost == null) {
      _showSnackBar('Please enter a valid cost', isError: true);
      return;
    }
    
    Navigator.of(context).pop();
    
    setState(() {
      isLoading = true;
    });
    
    try {
      await supabase.from('skills').insert({
        'name': nameController.text,
        'description': descriptionController.text,
        'cost': cost,
        'category': selectedCategory,
        'user_id': userId.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'Active',
      });
      
      if (mounted) {
        _showSnackBar('Skill added successfully!');
        _refreshSkills();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error adding skill: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[50]!,
                Colors.white,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2196F3),
                Color(0xFF1976D2),
                Color(0xFF0D47A1),
              ],
            ),
          ),
        ),
        elevation: 0,
        title: Text(
          'My Skills',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _refreshSkills,
              tooltip: 'Refresh Skills',
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2196F3),
              Color(0xFF1976D2),
              Color(0xFF0D47A1),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddSkillDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[50]!,
              Colors.white,
            ],
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: skillsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            } else if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final skills = snapshot.data!;
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsHeader(skills.length),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: skills.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildSkillCard(skills[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2196F3).withOpacity(0.1),
                  const Color(0xFF1976D2).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF2196F3),
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Skills Created',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share your expertise with the community',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.withOpacity(0.1),
                  Colors.red.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error loading skills',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.red[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2196F3).withOpacity(0.1),
                  const Color(0xFF1976D2).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 72,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No skills yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start sharing your expertise!\nTap the + button to add your first skill.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2196F3).withOpacity(0.1),
                        const Color(0xFF1976D2).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getCategoryIcon(skill['category']),
                    color: const Color(0xFF2196F3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    skill['name'] ?? 'Unnamed Skill',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D29),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2196F3),
                        Color(0xFF1976D2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${skill['cost'] ?? 0} credits',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              skill['description'] ?? 'No description available',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                skill['category'] ?? 'Uncategorized',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Cooking & Baking':
        return Icons.restaurant_rounded;
      case 'Fitness':
        return Icons.fitness_center_rounded;
      case 'IT & Tech':
        return Icons.computer_rounded;
      case 'Languages':
        return Icons.language_rounded;
      case 'Music & Audio':
        return Icons.music_note_rounded;
      case 'Art & Design':
        return Icons.palette_rounded;
      case 'Business':
        return Icons.business_rounded;
      case 'Photography':
        return Icons.camera_alt_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}
