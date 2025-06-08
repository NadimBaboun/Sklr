import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Skills/skillInfo.dart';
import 'package:sklr/database/database.dart';
import '../database/models.dart';
import 'package:sklr/Profile/user.dart';

class SearchResultsPage extends StatefulWidget {
  final String initialSearch;
  final String? initialCategory;

  const SearchResultsPage({
    Key? key,
    required this.initialSearch,
    this.initialCategory,
  }) : super(key: key);

  @override
  _SearchResultsPageState createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> 
    with TickerProviderStateMixin {
  static const int ALL_TAB = 0;
  static const int SKILLS_TAB = 1;
  static const int USERS_TAB = 2;

  late TabController _tabController;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 1000);
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch;
    _selectedCategory = widget.initialCategory;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _setupAnimations();
    _fetchSearchResults();
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

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _isLoading = true;
      });
      _fetchSearchResults();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSearchResults() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await DatabaseHelper.searchResults(
        _searchController.text.trim(),
        category: _selectedCategory,
        minPrice: _priceRange.start.toInt(),
        maxPrice: _priceRange.end.toInt(),
        includeUsers: true,
      );

      setState(() {
        if (_tabController.index == ALL_TAB) {
          _searchResults = results;
        } else if (_tabController.index == SKILLS_TAB) {
          _searchResults = results.where((result) => result['result_type'] == 'skill').toList();
        } else if (_tabController.index == USERS_TAB) {
          _searchResults = results.where((result) => result['result_type'] == 'user').toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching search results: $e');
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  Widget _buildSkillCard(Map<String, dynamic> skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Skillinfo(id: skill['id']),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill['name'] ?? 'Unnamed Skill',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1D29),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            skill['category'] ?? 'Uncategorized',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
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
                        '${(skill['cost'] ?? 0).toInt()} credits',
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
                FutureBuilder<DatabaseResponse>(
                  future: DatabaseHelper.fetchUserFromId(skill['user_id']),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Container(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2196F3),
                          ),
                        ),
                      );
                    }
                    
                    final user = userSnapshot.data!.data;
                    return Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
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
                          child: ClipOval(
                            child: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                              ? Image.network(
                                  user['avatar_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildUserInitial(user['username']);
                                  },
                                )
                              : _buildUserInitial(user['username']),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          user['username'] ?? 'Unknown User',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInitial(String? username) {
    return Container(
      color: const Color(0xFF2196F3).withOpacity(0.1),
      child: Center(
        child: Text(
          (username ?? 'U')[0].toUpperCase(),
          style: GoogleFonts.poppins(
            color: const Color(0xFF2196F3),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final username = user['username'] ?? 'Unknown User';
    final avatar = user['avatar_url'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserPage(userId: int.parse(user['id'].toString())),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
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
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: avatar != null && avatar.toString().isNotEmpty
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildLargeUserInitial(username);
                            },
                          )
                        : _buildLargeUserInitial(username),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFF1A1D29),
                        ),
                      ),
                      if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            user['bio'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeUserInitial(String username) {
    return Container(
      color: const Color(0xFF2196F3).withOpacity(0.1),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2196F3),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Container(
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
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
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
        child: Center(
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
                      const Color(0xFF2196F3).withOpacity(0.1),
                      const Color(0xFF1976D2).withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No results found',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term or filter',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return result['result_type'] == 'skill' 
                  ? _buildSkillCard(result) 
                  : _buildUserListItem(result);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Search Results',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF1A1D29),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search for skills or users...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF2196F3),
                          size: 24,
                        ),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _fetchSearchResults();
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                    ),
                    onSubmitted: (_) => _fetchSearchResults(),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Skills'),
                    Tab(text: 'Users'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchResults(), // ALL tab
          _buildSearchResults(), // SKILLS tab
          _buildSearchResults(), // USERS tab
        ],
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
      default:
        return Icons.category_rounded;
    }
  }
}
