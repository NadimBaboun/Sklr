import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/database/userIdStorage.dart';

class AddSkillPage extends StatefulWidget {
  const AddSkillPage({super.key});
  
  @override
  AddSkillPageState createState() => AddSkillPageState();
}

class AddSkillPageState extends State<AddSkillPage> with TickerProviderStateMixin {
  String skillname = '';
  String skilldescription = '';
  double? skillcost;
  int? loggedInUserId;
  String? chosenCategory;
  String? errorMessage;
  bool isLoading = false;
  
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<String> _choices = [
    'Cooking & Baking',
    'Fitness',
    'IT & Tech', 
    'Languages',
    'Music & Audio',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserId();
    _loadCategories();
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

  Future<void> _loadUserId() async {
    final userId = await UserIdStorage.getLoggedInUserId();
    setState(() {
      loggedInUserId = userId;
    });
  }

  Future<void> _loadCategories() async {
    try {
      final result = await DatabaseHelper.fetchCategories();
      if (result.isNotEmpty) {
        setState(() {
          _choices = result.map((category) => category['name'] as String).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;
    
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create New Skill",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 32.0 : 20.0,
                  vertical: 24.0
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    _buildSkillForm(),
                    const SizedBox(height: 24),
                    if (errorMessage != null) _buildErrorMessage(),
                    if (errorMessage != null) const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2196F3).withOpacity(0.05),
            const Color(0xFF1976D2).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Your Expertise',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a skill listing to help others learn from your experience',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillForm() {
    return Container(
      padding: const EdgeInsets.all(28),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(
            label: 'Skill Title',
            hint: 'Enter a clear, descriptive title for your skill',
            icon: Icons.title_rounded,
            maxLength: 40,
            onChanged: (value) => setState(() => skillname = value),
          ),
          const SizedBox(height: 24),
          _buildFormField(
            label: 'Description',
            hint: 'Describe what you\'ll teach and what students will learn',
            icon: Icons.description_rounded,
            maxLines: 4,
            maxLength: 150,
            onChanged: (value) => setState(() => skilldescription = value),
          ),
          const SizedBox(height: 24),
          _buildFormField(
            label: 'Cost (Credits)',
            hint: 'Set a fair price for your expertise',
            icon: Icons.account_balance_wallet_rounded,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                if (value.isNotEmpty) {
                  skillcost = double.tryParse(value);
                } else {
                  skillcost = null;
                }
              });
            },
          ),
          const SizedBox(height: 24),
          _buildCategoryDropdown(),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1D29),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: const Color(0xFF1A1D29),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 15,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  color: const Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFF2196F3).withOpacity(0.02),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              counterStyle: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1D29),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              width: 1,
            ),
            color: const Color(0xFF2196F3).withOpacity(0.02),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: chosenCategory,
              hint: Text(
                'Select a category for your skill',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 15,
                ),
              ),
              isExpanded: true,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              items: _choices.map((String choice) {
                return DropdownMenuItem<String>(
                  value: choice,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(choice),
                          color: const Color(0xFF2196F3),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        choice,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: const Color(0xFF1A1D29),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  chosenCategory = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: Colors.red[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: GoogleFonts.poppins(
                color: Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleCreateSkill,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Creating...",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    "Create Skill",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateSkill() async {
    setState(() {
      errorMessage = null;
      isLoading = true;
    });
    
    // Form validation
    final skillname = this.skillname.trim();
    final skilldescription = this.skilldescription.trim();
    final skillcost = this.skillcost;
    
    // Check for empty fields
    if (skillname.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a skill name';
        isLoading = false;
      });
      return;
    }
    
    if (skilldescription.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a description';
        isLoading = false;
      });
      return;
    }
    
    if (chosenCategory == null) {
      setState(() {
        errorMessage = 'Please select a category';
        isLoading = false;
      });
      return;
    }
    
    if (skillcost == null || skillcost <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid cost (greater than 0)';
        isLoading = false;
      });
      return;
    }
    
    if (loggedInUserId == null) {
      setState(() {
        errorMessage = 'User ID not found. Please log in again.';
        isLoading = false;
      });
      return;
    }
    
    try {
      // Check if skill name already exists for this user
      bool skillExists = await DatabaseHelper.checkSkillName(
        skillname, 
        loggedInUserId
      );
      
      if (skillExists) {
        setState(() {
          errorMessage = 'You already have a skill with this name';
          isLoading = false;
        });
        return;
      }
      
      // Insert the skill with proper parameters
      final response = await DatabaseHelper.insertSkill(
        loggedInUserId!,
        skillname,
        skilldescription,
        chosenCategory!,
        skillcost
      );
      
      if (response.success) {
        Navigator.pop(context, true); // Pass true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skill created successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF2196F3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        setState(() {
          errorMessage = 'Failed to add skill: ${response.message}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
      debugPrint('Error adding skill: $e');
    }
  }

  IconData _getCategoryIcon(String category) {
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
        return Icons.category_rounded;
    }
  }
}
