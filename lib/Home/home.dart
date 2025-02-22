import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Home/categoryListings.dart';
import 'package:sklr/Home/searchResult.dart';
import 'package:sklr/Util/navigationbar-bar.dart';
import 'package:sklr/database/userIdStorage.dart';
import 'package:sklr/database/database.dart';
import 'package:sklr/Skills/skillInfo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? loggedInUserId;
  String? username;
  int limit = 10;
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
    if (loggedInUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(180.0),
        child: AppBar(
          backgroundColor: const Color(0xFF6296FF),
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${username ?? "Unknown User"}',
                    style: GoogleFonts.mulish(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Let's find the best talent for you",
                    style: GoogleFonts.mulish(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchResultsPage(search: value),
                            ),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search service',
                        hintStyle: GoogleFonts.mulish(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF6296FF),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: RefreshIndicator(
          color: const Color(0xFF6296FF),
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            key: _scrollKey,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Categories',
                  style: GoogleFonts.mulish(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                const ServiceCategoryCards(),
                const SizedBox(height: 32),
                Text(
                  'Recent Listings',
                  style: GoogleFonts.mulish(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                RecentListings(limit: limit),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6296FF),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        setState(() {
                          limit += 10;
                        });
                      },
                      child: Text(
                        'Load more',
                        style: GoogleFonts.mulish(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }
}

class ServiceCategoryCards extends StatefulWidget {
  const ServiceCategoryCards({Key? key}) : super(key: key);

  @override
  _serviceCategoryState createState() => _serviceCategoryState();
}

class _serviceCategoryState extends State<ServiceCategoryCards> {
  List<Widget> _buildAsyncServiceCategoryCards(
      BoxConstraints constraints, List<Map<String, dynamic>> categories) {
    return categories
        .map(
          (category) => InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryListingsPage(categoryName: category['name']),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  width: 90,
                  height: 90,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/${category['asset']}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category['name'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mulish(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.fetchCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Failed to load categories',
              style: GoogleFonts.mulish(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          );
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              children: _buildAsyncServiceCategoryCards(constraints, snapshot.data!),
            );
          },
        );
      },
    );
  }
}

class RecentListings extends StatefulWidget {
  final int limit;
  const RecentListings({Key? key, required this.limit}) : super(key: key);

  @override
  _recentListingsState createState() => _recentListingsState();
}

class _recentListingsState extends State<RecentListings> {
  Widget _skillListing(Map<String, dynamic> listing, Map<dynamic, dynamic> categoryMap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF6296FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/images/${categoryMap[listing['category']]}.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing['name'],
                        style: GoogleFonts.mulish(
                          color: Colors.black87,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing['description'],
                        style: GoogleFonts.mulish(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.4,
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
            FutureBuilder<DatabaseResponse>(
              future: DatabaseHelper.fetchUserFromId(listing['user_id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
                    ),
                  );
                } else if (snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6296FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'By ${snapshot.data!.data['username']}',
                      style: GoogleFonts.mulish(
                        color: const Color(0xFF6296FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return Text(
                  'Unknown Provider',
                  style: GoogleFonts.mulish(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildListings(
    BoxConstraints constraints,
    List<Map<String, dynamic>> listings,
    Map<dynamic, dynamic> categoryMap,
  ) {
    return listings.map((listing) => InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => Skillinfo(id: listing['id'])),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: _skillListing(listing, categoryMap),
      ),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: Future.wait([
        DatabaseHelper.fetchRecentListings(widget.limit),
        DatabaseHelper.fetchCategories(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Failed to load listings',
              style: GoogleFonts.mulish(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final listings = data[0] as List<Map<String, dynamic>>;
        final categoryMap = {
          for (var category in data[1]) category['name']: category['asset']
        };

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: _buildListings(constraints, listings, categoryMap),
            );
          },
        );
      },
    );
  }
}
