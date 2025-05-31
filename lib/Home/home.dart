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

class _HomePageState extends State<HomePage> {
  int? loggedInUserId;
  String? username;
  final ScrollController _scrollController = ScrollController();
  final _scrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadUserIdAndUsername();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    if (loggedInUserId == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(
          color: Color(0xFF2196F3),
          strokeWidth: 3,
        )),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(size.height * 0.24), // Increased height to fix overflow
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2196F3),
                const Color(0xFF2196F3).withOpacity(0.8),
              ],
            ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: size.height * 0.24, // Match preferredSize height
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0, vertical: 10.0), // Reduced vertical padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${username ?? "Unknown User"} 👋',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Let's find the best talent for you",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 48, // Adjusted height for better alignment
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SearchResultsPage(initialSearch: value),
                              ),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search service',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF2196F3),
                            size: 24,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        key: _scrollKey,
        physics: const BouncingScrollPhysics(),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0), // Further reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service Categories',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                    fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
                const SizedBox(height: 8), // Further reduced space
              const ServiceCategoryCards(),
                const SizedBox(height: 16), // Further reduced space
                _buildSectionHeader('Recent Listings', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllListingsPage(title: 'Recent Listings'),
                    ),
                  );
                }),
                const SizedBox(height: 8), // Further reduced space
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const RecentListings(),
                ),
                const SizedBox(height: 16), // Further reduced space
                _buildSectionHeader('Popular Services', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllServicesPage(title: 'Popular Services'),
                    ),
                  );
                }),
                const SizedBox(height: 8), // Further reduced space
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const PopularServices(),
              ),
              const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, Function()? onViewAll) {
    return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
          title,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
            fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
        if (onViewAll != null)
          InkWell(
            onTap: onViewAll,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'View All',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2196F3),
                      fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF2196F3),
                    size: 10,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

}

class ServiceCategoryCards extends StatefulWidget {
  const ServiceCategoryCards({super.key});

  @override
  _serviceCategoryState createState() => _serviceCategoryState();
}

class _serviceCategoryState extends State<ServiceCategoryCards> {
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

  Future<void> _fetchCategories() async {
    try {
      final categories = await DatabaseHelper.fetchCategories();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _categories = categories;
          _pageCount = (categories.length / 6).ceil();
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          strokeWidth: 3,
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }
    
    if (_categories.isEmpty) {
      return Center(
        child: Text(
          'No categories available',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }
    
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            key: PageStorageKey('categoryPageView'),
            controller: _pageController,
            itemCount: _pageCount,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * 6;
              final endIndex = (startIndex + 6 <= _categories.length) 
                  ? startIndex + 6 
                  : _categories.length;
              
              final pageItems = _categories.sublist(startIndex, endIndex);
              
              return GridView.builder(
                key: ValueKey('grid_page_$pageIndex'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: pageItems.length,
                itemBuilder: (context, index) => _buildCategoryCard(pageItems[index], pageIndex * 6 + index),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
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
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? const Color(0xFF2196F3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
        if (_pageCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Tap dots or swipe to view more categories',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    return InkWell(
      key: ValueKey('category_${category['name']}_$index'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CategoryListingsPage(categoryName: category['name']),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
              borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        spreadRadius: 2,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
            width: 85,
            height: 85,
                  child: Padding(
              padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/${category['asset']}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
          const SizedBox(height: 10),
          Container(
            height: 45,
            width: 100,
            alignment: Alignment.center,
            child: Text(
                  category['name'],
                  textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                fontSize: 13,
                    fontWeight: FontWeight.w600,
              ),
                  ),
                ),
              ],
            ),
    );
  }
}

class RecentListings extends StatefulWidget {
  const RecentListings({Key? key}) : super(key: key);

  @override
  _recentListingsState createState() => _recentListingsState();
}

class _recentListingsState extends State<RecentListings> {
  Widget _skillListing(
      Map<String, dynamic> listing, Map<dynamic, dynamic> categoryMap) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'listing-image-${listing['id']}',
                  child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                  ),
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/${categoryMap[listing['category']]}.png',
                    fit: BoxFit.contain,
                  ),
                ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing['name'],
                        style: GoogleFonts.poppins(
                          color: Colors.black.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing['description'],
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 14,
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            FutureBuilder<DatabaseResponse>(
              future: DatabaseHelper.fetchUserFromId(listing['user_id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                  );
                } else if (snapshot.hasData) {
                      return Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                              shape: BoxShape.circle,
                    ),
                            child: Center(
                    child: Text(
                                snapshot.data!.data['username']
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2196F3),
                                  fontSize: 12,
                        fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'By ${snapshot.data!.data['username']}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                  );
                }
                return Text(
                  'Unknown Provider',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
                ),
                
                // Cost display
                if (listing['cost'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${listing['cost']} credits',
                      style: GoogleFonts.poppins(
                        color: Colors.green[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: Future.wait([
        DatabaseHelper.fetchRecentListings(10),
        DatabaseHelper.fetchCategories(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              strokeWidth: 3,
            ),
          );
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Failed to load listings',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final listings = data[0];
        final categoryMap = {
          for (var category in data[1]) category['name']: category['asset']
        };

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) =>
                          Skillinfo(id: listings[index]['id'])),
                );
              },
              child: _skillListing(listings[index], categoryMap),
            );
          },
        );
      },
    );
  }
}

class PopularServices extends StatelessWidget {
  const PopularServices({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.searchUsers("").then((users) {
        // Sort users by some metric (could be rating in a real app)
        users.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        // Take the first 5 users
        return users.take(5).toList();
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              strokeWidth: 3,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No popular services found',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final user = snapshot.data![index];
            return Container(
              width: 300,
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          width: 60,
                          height: 60,
                          child: Icon(
                            Icons.person,
                            color: const Color(0xFF2196F3),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['username'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['email'] ?? '',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                      Text(
                        user['bio'],
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.4,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to user profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserPage(userId: user['id']),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                            child: Text(
                        'View Profile',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AllListingsPage extends StatelessWidget {
  final String title;
  
  const AllListingsPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.fetchRecentListings(50), // Load more listings
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
                  fontSize: 16,
                ),
              ),
            );
          }
          
          final listings = snapshot.data!;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
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
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.category,
                                    color: const Color(0xFF2196F3),
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing['name'] ?? 'Unnamed listing',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      listing['description'] ?? 'No description',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FutureBuilder<DatabaseResponse>(
                                future: DatabaseHelper.fetchUserFromId(listing['user_id']),
                                builder: (context, userSnapshot) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'By ${userSnapshot.hasData ? userSnapshot.data!.data['username'] : 'Unknown'}',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF2196F3),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (listing['cost'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${listing['cost']} credits',
                                    style: GoogleFonts.poppins(
                                      color: Colors.green,
                                      fontSize: 16,
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


class AllServicesPage extends StatelessWidget {
  final String title;
  
  const AllServicesPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
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
                  fontSize: 16,
                ),
              ),
            );
          }
          
          final users = snapshot.data!;
          users.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to user profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserPage(userId: user['id']),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(35),
                            ),
                            child: Center(
                              child: Text(
                                user['username'] != null && user['username'].toString().isNotEmpty
                                    ? user['username'].toString()[0].toUpperCase()
                                    : '?',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF2196F3),
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                          const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  user['username'] ?? 'Unknown user',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                ),
                              ),
                                const SizedBox(height: 4),
                                if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                              Text(
                                    user['bio'],
                                style: GoogleFonts.poppins(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2196F3).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'View Profile',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF2196F3),
                                          fontSize: 14,
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
