import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Skills/skillInfo.dart';
import 'package:sklr/database/database.dart';
import '../database/models.dart';
import 'package:sklr/Profile/OtherProfile.dart';

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

class _SearchResultsPageState extends State<SearchResultsPage> with SingleTickerProviderStateMixin {
  static const int ALL_TAB = 0;
  static const int SKILLS_TAB = 1;
  static const int USERS_TAB = 2;

  late TabController _tabController;
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
    _fetchSearchResults();
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
      // Always include users in the search to filter by tab later
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
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Skillinfo(id: skill['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6296FF).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                    child: Icon(
                      _getCategoryIcon(skill['category']),
                      color: const Color(0xFF6296FF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill['name'] ?? 'Unnamed Skill',
                          style: GoogleFonts.mulish(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          skill['category'] ?? 'Uncategorized',
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      '£${(skill['cost'] ?? 0).toStringAsFixed(2)}',
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6296FF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                skill['description'] ?? 'No description available',
                style: GoogleFonts.mulish(
                  fontSize: 14,
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
                    return const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6296FF),
                        ),
                      ),
                    );
                  }

                  final user = userSnapshot.data!.data;
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF6296FF).withOpacity(0.1),
                        backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                          ? NetworkImage(user['avatar_url'])
                          : null,
                        child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
                          ? Text(
                              (user['username'] ?? 'U')[0].toUpperCase(),
                              style: GoogleFonts.mulish(
                                color: const Color(0xFF6296FF),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        user['username'] ?? 'Unknown User',
                        style: GoogleFonts.mulish(
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
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtherProfile(userId: user['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6296FF).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF6296FF).withOpacity(0.1),
                backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                  ? NetworkImage(user['avatar_url'])
                  : null,
                child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
                  ? Text(
                      (user['username'] ?? 'U')[0].toUpperCase(),
                      style: GoogleFonts.mulish(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6296FF),
                      ),
                    )
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['username'] ?? 'Unnamed User',
                      style: GoogleFonts.mulish(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (user['email'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          user['email'],
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          user['bio'],
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6296FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF6296FF),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: GoogleFonts.mulish(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or filter',
              style: GoogleFonts.mulish(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return ListView.builder(
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: result['result_type'] == 'skill' 
              ? _buildSkillCard(result) 
              : _buildUserCard(result),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Search Results',
          style: GoogleFonts.mulish(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for skills or users...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6296FF)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _fetchSearchResults();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                  ),
                  onSubmitted: (_) => _fetchSearchResults(),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF6296FF),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFF6296FF),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Skills'),
                  Tab(text: 'Users'),
                ],
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
        return Icons.restaurant;
      case 'Fitness':
        return Icons.fitness_center;
      case 'IT & Tech':
        return Icons.computer;
      case 'Languages':
        return Icons.language;
      case 'Music & Audio':
        return Icons.music_note;
      default:
        return Icons.category;
    }
  }
}
