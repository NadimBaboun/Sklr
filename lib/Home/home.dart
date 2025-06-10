import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Home/categoryListings.dart';
import 'package:sklr/Home/searchResult.dart';
import 'package:sklr/Util/navigationbar-bar.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/Skills/skillInfo.dart';
import '../database/models.dart';
import '../Profile/user.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int? loggedInUserId;
  String? username;
  final ScrollController _scrollController = ScrollController();
  final _scrollKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndUsername();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndUsername() async {
    final userId = await UserIdStorage.getLoggedInUserId();
    if (userId != null) {
      final response = await DatabaseHelper.fetchUserFromId(userId);

      if (response.success) {
        final userData = response.data;
        setState(() {
          loggedInUserId = userId;
          username = userData['username'];
        });
      }
    }
  }

  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsPage(initialSearch: query.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isLargeScreen = size.width > 600;
        final isTablet = size.width > 768;
        final isDesktop = size.width > 1024;
        
        if (loggedInUserId == null) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      color: const Color(0xFF2196F3),
                      strokeWidth: isLargeScreen ? 4 : 3,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 24 : 20),
                  Text(
                    'Loading your workspace...',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.grey[50],
            body: Column(
              children: [
                // Responsive Header Section
                Container(
                  
                  height: size.height * (isDesktop ? 0.24 : isTablet ? 0.22 : 0.25), // Maximized header height

                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2196F3),
                        const Color(0xFF1976D2),
                        const Color(0xFF0D47A1),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
                      bottomRight: Radius.circular(isDesktop ? 32 : isTablet ? 28 : 24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.2),
                        blurRadius: isLargeScreen ? 16 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32.0 : isTablet ? 28.0 : 20.0,
                        vertical: isDesktop ? 20.0 : isTablet ? 18.0 : 16.0,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back! 👋',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: isLargeScreen ? 4 : 2),
                                      Text(
                                        username ?? "User",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(isDesktop ? 16 : isTablet ? 14 : 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: isDesktop ? 28 : isTablet ? 26 : 24,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 14 : isTablet ? 12 : 10),
                            Text(
                              "Find exceptional talent",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isDesktop ? 20 : isTablet ? 18 : 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: isDesktop ? 20 : isTablet ? 18 : 14),
                            // Responsive Search Bar
                            Container(
                              height: isDesktop ? 48 : isTablet ? 44 : 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onSubmitted: _performSearch,
                                style: TextStyle(fontSize: isDesktop ? 15 : isTablet ? 14 : 13),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Search for services...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey[600],
                                    size: isDesktop ? 20 : isTablet ? 18 : 16,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.grey[600],
                                            size: isDesktop ? 18 : isTablet ? 16 : 14,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : IconButton(
                                          icon: Icon(
                                            Icons.arrow_forward,
                                            color: const Color(0xFF2196F3),
                                            size: isDesktop ? 18 : isTablet ? 16 : 14,
                                          ),
                                          onPressed: () => _performSearch(_searchController.text),
                                        ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: isDesktop ? 12 : isTablet ? 10 : 8,
                                    horizontal: isDesktop ? 16 : isTablet ? 14 : 12,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    key: _scrollKey,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32.0 : isTablet ? 28.0 : 20.0,
                        vertical: isDesktop ? 20.0 : isTablet ? 18.0 : 16.0,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Service Categories', null),
                            SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                            const ModernServiceCategoryCards(),
                            SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
                            _buildSectionHeader('Recent Listings', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllListingsPage(title: 'Recent Listings'),
                                ),
                              );
                            }),
                            SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                            Container(
                              height: isDesktop ? 320 : isTablet ? 300 : 280,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.06),
                                    spreadRadius: 1,
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const ModernRecentListings(),
                            ),
                            SizedBox(height: isDesktop ? 32 : isTablet ? 28 : 24),
                            _buildSectionHeader('Popular Services', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllServicesPage(title: 'Popular Services'),
                                ),
                              );
                            }),
                            SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                            Container(
                              height: isDesktop ? 320 : isTablet ? 300 : 280,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.06),
                                    spreadRadius: 1,
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const ModernPopularServices(),
                            ),
                            SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Function()? onViewAll) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isDesktop = size.width > 1024;
        final isTablet = size.width > 768;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: isDesktop ? 24 : isTablet ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onViewAll != null)
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 18 : isTablet ? 16 : 14,
                    vertical: isDesktop ? 10 : isTablet ? 9 : 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3).withOpacity(0.1),
                        const Color(0xFF2196F3).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF2196F3),
                          fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: isDesktop ? 8 : isTablet ? 7 : 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: const Color(0xFF2196F3),
                        size: isDesktop ? 14 : isTablet ? 13 : 12,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Maximized Service Category Cards Widget with 4 Icons Display
class ModernServiceCategoryCards extends StatefulWidget {
  const ModernServiceCategoryCards({super.key});

  @override
  _ModernServiceCategoryState createState() => _ModernServiceCategoryState();
}

class _ModernServiceCategoryState extends State<ModernServiceCategoryCards> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  int _pageCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  // Optimized for 4 icons display
  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 4; // Desktop: 4 columns
    if (screenWidth > 900) return 4;  // Large tablet: 4 columns
    if (screenWidth > 600) return 4;  // Tablet: 4 columns
    return 2; // Mobile: 2 columns
  }

  int _getItemsPerPage(double screenWidth) {
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    return crossAxisCount * 2; // 2 rows for maximum display
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await DatabaseHelper.fetchCategories();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _categories = categories;
          final size = MediaQuery.of(context).size;
          final itemsPerPage = _getItemsPerPage(size.width);
          _pageCount = (categories.length / itemsPerPage).ceil();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load categories';
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final crossAxisCount = _getCrossAxisCount(size.width);
        final itemsPerPage = _getItemsPerPage(size.width);
        final isDesktop = size.width > 1024;
        final isTablet = size.width > 768;
        final isLargeScreen = size.width > 600;

        // Maximized container height for better display
        final containerHeight = isDesktop ? 380.0 : isTablet ? 360.0 : isLargeScreen ? 340.0 : 320.0;

        if (_isLoading) {
          return Container(
            height: containerHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                strokeWidth: 3,
              ),
            ),
          );
        }

        if (_error != null || _categories.isEmpty) {
          return Container(
            height: containerHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: isDesktop ? 48 : isTablet ? 44 : 40,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
                  Text(
                    _error ?? 'No categories available',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Container(
              height: containerHeight,
              width: double.infinity, // Maximize container width
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isDesktop ? 24 : isTablet ? 22 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pageCount,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * itemsPerPage;
                  final endIndex = (startIndex + itemsPerPage <= _categories.length)
                      ? startIndex + itemsPerPage
                      : _categories.length;

                  final pageItems = _categories.sublist(startIndex, endIndex);

                  return GridView.builder(
                    padding: EdgeInsets.all(isDesktop ? 24 : isTablet ? 22 : 20),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: isDesktop ? 1.1 : isTablet ? 1.05 : isLargeScreen ? 1.0 : 0.95,
                      mainAxisSpacing: isDesktop ? 20 : isTablet ? 18 : 16,
                      crossAxisSpacing: isDesktop ? 20 : isTablet ? 18 : 16,
                    ),
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) => _buildModernCategoryCard(
                      pageItems[index],
                      pageIndex * itemsPerPage + index,
                    ),
                  );
                },
              ),
            ),
            if (_pageCount > 1) ...[
              SizedBox(height: isDesktop ? 16 : isTablet ? 14 : 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pageCount,
                  (index) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == index ? (isDesktop ? 24 : isTablet ? 22 : 20) : (isDesktop ? 8 : isTablet ? 7 : 6),
                      height: isDesktop ? 8 : isTablet ? 7 : 6,
                      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 4 : isTablet ? 3.5 : 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isDesktop ? 4 : isTablet ? 3.5 : 3),
                        color: _currentPage == index
                            ? const Color(0xFF2196F3)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isDesktop ? 8 : isTablet ? 7 : 6),
              Text(
                'Swipe to explore more categories',
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: isDesktop ? 12 : isTablet ? 11 : 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildModernCategoryCard(Map<String, dynamic> category, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isDesktop = size.width > 1024;
        final isTablet = size.width > 768;
        final isLargeScreen = size.width > 600;

        // Optimized icon sizes for 4-icon display
        final iconSize = isDesktop ? 65.0 : isTablet ? 60.0 : isLargeScreen ? 55.0 : 50.0;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryListingsPage(categoryName: category['name']),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 20 : isTablet ? 18 : 16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.06),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3).withOpacity(0.1),
                        const Color(0xFF2196F3).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(iconSize / 3),
                  ),
                  padding: EdgeInsets.all(iconSize * 0.25),
                  child: Image.asset(
                    'assets/images/${category['asset']}.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: isDesktop ? 14 : isTablet ? 12 : 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : isTablet ? 6 : 4),
                  child: Text(
                    category['name'],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: isDesktop ? 13 : isTablet ? 12 : 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Optimized Recent Listings with Smaller Icons
class ModernRecentListings extends StatelessWidget {
  const ModernRecentListings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: Future.wait([
        DatabaseHelper.fetchRecentListings(10),
        DatabaseHelper.fetchCategories(),
      ]),
      builder: (context, snapshot) {
        final size = MediaQuery.of(context).size;
        final isLargeScreen = size.width > 600;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                strokeWidth: 3,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: isLargeScreen ? 48 : 40,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: isLargeScreen ? 16 : 12),
                  Text(
                    'No recent listings found',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: isLargeScreen ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final listings = data[0];
        final categoryMap = {
          for (var category in data[1]) category['name']: category['asset']
        };

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 20 : 16,
              vertical: isLargeScreen ? 20 : 16,
            ),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Skillinfo(id: listings[index]['id']),
                    ),
                  );
                },
                child: _buildModernListingCard(listings[index], categoryMap),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildModernListingCard(Map<String, dynamic> listing, Map<dynamic, dynamic> categoryMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isLargeScreen = size.width > 600;
        final isTablet = size.width > 768;
        
        // Smaller responsive card and icon sizing
        final cardWidth = isTablet ? 300 : isLargeScreen ? 280 : 260;
        final iconSize = isTablet ? 45.0 : isLargeScreen ? 40.0 : 35.0;

        return Container(
          width: cardWidth.toDouble(),
          margin: EdgeInsets.only(right: isLargeScreen ? 16 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
            borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.06),
                spreadRadius: 0,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'listing-image-${listing['id']}',
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2196F3).withOpacity(0.1),
                              const Color(0xFF2196F3).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(iconSize / 2.5),
                        ),
                        width: iconSize,
                        height: iconSize,
                        padding: EdgeInsets.all(iconSize * 0.25),
                        child: Image.asset(
                          'assets/images/${categoryMap[listing['category']] ?? 'default'}.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: isLargeScreen ? 14 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing['name'] ?? 'Unknown Service',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: isTablet ? 16 : isLargeScreen ? 15 : 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isLargeScreen ? 6 : 4),
                          Text(
                            listing['description'] ?? 'No description available',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: isTablet ? 13 : isLargeScreen ? 12 : 11,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isLargeScreen ? 16 : 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<DatabaseResponse>(
                      future: DatabaseHelper.fetchUserFromId(listing['user_id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SizedBox(
                            width: isLargeScreen ? 16 : 14,
                            height: isLargeScreen ? 16 : 14,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                            ),
                          );
                        }

                        if (snapshot.hasData) {
                          return Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isLargeScreen ? 10 : 8,
                                vertical: isLargeScreen ? 6 : 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2196F3).withOpacity(0.1),
                                    const Color(0xFF2196F3).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(isLargeScreen ? 14 : 12),
                                border: Border.all(
                                  color: const Color(0xFF2196F3).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: isLargeScreen ? 16 : 14,
                                    height: isLargeScreen ? 16 : 14,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2196F3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        snapshot.data!.data['username']
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: isLargeScreen ? 9 : 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isLargeScreen ? 6 : 5),
                                  Flexible(
                                    child: Text(
                                      snapshot.data!.data['username'],
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF2196F3),
                                        fontSize: isTablet ? 12 : isLargeScreen ? 11 : 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isLargeScreen ? 10 : 8,
                            vertical: isLargeScreen ? 6 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(isLargeScreen ? 14 : 12),
                          ),
                          child: Text(
                            'Unknown',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: isLargeScreen ? 11 : 10,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: isLargeScreen ? 8 : 6),
                    if (listing['cost'] != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 10 : 8,
                          vertical: isLargeScreen ? 6 : 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.1),
                              Colors.green.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(isLargeScreen ? 14 : 12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${listing['cost']} credits',
                          style: GoogleFonts.poppins(
                            color: Colors.green[700],
                            fontSize: isTablet ? 12 : isLargeScreen ? 11 : 10,
                            fontWeight: FontWeight.w700,
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
}

// Continue with other widgets (ModernPopularServices, AllListingsPage, AllServicesPage)...

// Responsive Popular Services Widget
class ModernPopularServices extends StatelessWidget {
  const ModernPopularServices({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.searchUsers("").then((users) {
        users.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        return users.take(5).toList();
      }),
      builder: (context, snapshot) {
        final size = MediaQuery.of(context).size;
        final isLargeScreen = size.width > 600;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isLargeScreen ? 28 : 24),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                strokeWidth: 3,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isLargeScreen ? 28 : 24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: isLargeScreen ? 56 : 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: isLargeScreen ? 20 : 16),
                  Text(
                    'No popular services found',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: isLargeScreen ? 18 : 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isLargeScreen ? 28 : 24),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 20,
              vertical: isLargeScreen ? 24 : 20,
            ),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final user = snapshot.data![index];
              return Container(
                width: isLargeScreen ? 360 : 320,
                margin: EdgeInsets.only(right: isLargeScreen ? 24 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 26 : 22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.08),
                      spreadRadius: 0,
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 28 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2196F3).withOpacity(0.1),
                                  const Color(0xFF2196F3).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(isLargeScreen ? 22 : 20),
                            ),
                            width: isLargeScreen ? 65 : 55,
                            height: isLargeScreen ? 65 : 55,
                            child: Center(
                              child: Text(
                                user['username'] != null && user['username'].toString().isNotEmpty
                                    ? user['username'].toString()[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF2196F3),
                                  fontSize: isLargeScreen ? 26 : 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isLargeScreen ? 20 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['username'] ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontSize: isLargeScreen ? 20 : 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isLargeScreen ? 6 : 4),
                                Text(
                                  user['email'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: isLargeScreen ? 16 : 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLargeScreen ? 24 : 20),
                      if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(isLargeScreen ? 18 : 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 14),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            user['bio'],
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: isLargeScreen ? 16 : 14,
                              height: 1.4,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserPage(userId: user['id']),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 14),
                            ),
                            padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 16 : 14),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            'View Profile',
                            style: GoogleFonts.poppins(
                              fontSize: isLargeScreen ? 17 : 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// All Listings Page with Responsive Design
class AllListingsPage extends StatelessWidget {
  final String title;

  const AllListingsPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isLargeScreen ? 22 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(isLargeScreen ? 24 : 20),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.fetchRecentListings(50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No listings available',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: isLargeScreen ? 18 : 16,
                ),
              ),
            );
          }

          final listings = snapshot.data!;

          return Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20.0 : 16.0),
            child: ListView.builder(
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Skillinfo(id: listing['id']),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLargeScreen ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: isLargeScreen ? 80 : 70,
                                height: isLargeScreen ? 80 : 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.category,
                                    color: const Color(0xFF2196F3),
                                    size: isLargeScreen ? 36 : 30,
                                  ),
                                ),
                              ),
                              SizedBox(width: isLargeScreen ? 20 : 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing['name'] ?? 'Unnamed listing',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: isLargeScreen ? 20 : 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: isLargeScreen ? 6 : 4),
                                    Text(
                                      listing['description'] ?? 'No description',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[700],
                                        fontSize: isLargeScreen ? 16 : 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isLargeScreen ? 20 : 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FutureBuilder<DatabaseResponse>(
                                future: DatabaseHelper.fetchUserFromId(listing['user_id']),
                                builder: (context, userSnapshot) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isLargeScreen ? 16 : 12,
                                      vertical: isLargeScreen ? 8 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
                                    ),
                                    child: Text(
                                      'By ${userSnapshot.hasData ? userSnapshot.data!.data['username'] : 'Unknown'}',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF2196F3),
                                        fontSize: isLargeScreen ? 16 : 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (listing['cost'] != null)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 16 : 12,
                                    vertical: isLargeScreen ? 8 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
                                  ),
                                  child: Text(
                                    '${listing['cost']} credits',
                                    style: GoogleFonts.poppins(
                                      color: Colors.green,
                                      fontSize: isLargeScreen ? 18 : 16,
                                      fontWeight: FontWeight.w600,
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
            ),
          );
        },
      ),
    );
  }
}

// All Services Page with Responsive Design
class AllServicesPage extends StatelessWidget {
  final String title;

  const AllServicesPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isLargeScreen ? 22 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(isLargeScreen ? 24 : 20),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.searchUsers(""),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No services available',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: isLargeScreen ? 18 : 16,
                ),
              ),
            );
          }

          final users = snapshot.data!;
          users.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

          return Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20.0 : 16.0),
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserPage(userId: user['id']),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLargeScreen ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isLargeScreen ? 80 : 70,
                            height: isLargeScreen ? 80 : 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isLargeScreen ? 40 : 35),
                            ),
                            child: Center(
                              child: Text(
                                user['username'] != null && user['username'].toString().isNotEmpty
                                    ? user['username'].toString()[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF2196F3),
                                  fontSize: isLargeScreen ? 32 : 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isLargeScreen ? 20 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['username'] ?? 'Unknown user',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isLargeScreen ? 20 : 18,
                                  ),
                                ),
                                SizedBox(height: isLargeScreen ? 6 : 4),
                                if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                                  Text(
                                    user['bio'],
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[700],
                                      fontSize: isLargeScreen ? 16 : 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                SizedBox(height: isLargeScreen ? 16 : 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isLargeScreen ? 16 : 12,
                                        vertical: isLargeScreen ? 8 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2196F3).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
                                      ),
                                      child: Text(
                                        'View Profile',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF2196F3),
                                          fontSize: isLargeScreen ? 16 : 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
