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
      return Directionality(
        textDirection: TextDirection.ltr,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Responsive Example',
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(220.0),
          child: AppBar(
            backgroundColor: const Color(0xFF6296FF),
            flexibleSpace: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'Hello, ${username ?? "Unknown User"}',
                        style: GoogleFonts.mulish(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth > 600 ? 28 : 20,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Let's find the best talent for you",
                        style: GoogleFonts.mulish(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth > 600 ? 36 : 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Adjusting the Search Bar
                      Flexible(
                        child: SizedBox(
                          height: 50,
                          width: constraints.maxWidth * 0.8,
                          child: TextField(
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SearchResultsPage(
                                      search: value,
                                    ),
                                  ),
                                );
                              }
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF6296FF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Search service',
                              hintStyle: GoogleFonts.mulish(
                                textStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize:
                                      constraints.maxWidth > 600 ? 18 : 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _scrollController,
                key: _scrollKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service Categories',
                          style: GoogleFonts.mulish(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const ServiceCategoryCards(), // dynamically loaded categories
                    const SizedBox(height: 20),
                    Text(
                      'Recent Listings',
                      style: GoogleFonts.mulish(
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RecentListings(limit: limit),
                    Center(
                        child: Padding(
                      // load more button
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6296FF),
                        ),
                        onPressed: () {
                          setState(() {
                            limit += 10;
                          });
                        },
                        child: Text('Load more!',
                        style: TextStyle(
                          color: Colors.white
                        )),
                      ),
                    )),
                  ],
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 0),
      ),
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
                      builder: (context) => CategoryListingsPage(
                          categoryName: category['name'])));
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  width: constraints.maxWidth > 600 ? 80 : 74,
                  height: constraints.maxWidth > 600 ? 80 : 74,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/images/${category['asset']}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category['name'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mulish(
                    textStyle: TextStyle(
                      color: Colors.black,
                      fontSize: constraints.maxWidth > 600 ? 15 : 13,
                      fontWeight: FontWeight.w300,
                    ),
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
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load categories.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Failed to load categories.'));
          } else {
            final categories = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  children:
                      _buildAsyncServiceCategoryCards(constraints, categories),
                );
              },
            );
          }
        });
  }
}

class RecentListings extends StatefulWidget {
  final int limit;
  const RecentListings({Key? key, required this.limit}) : super(key: key);

  @override
  _recentListingsState createState() => _recentListingsState();
}

class _recentListingsState extends State<RecentListings> {
  Widget _skillListing(
      Map<String, dynamic> listing, Map<dynamic, dynamic> categoryMap) {
    return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                width: 64,
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/${categoryMap[listing['category']]}.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                listing['name'],
                style: GoogleFonts.mulish(
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                listing['description'],
                style: GoogleFonts.mulish(
                  color: Colors.black,
                  fontWeight: FontWeight.w200,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              FutureBuilder<DatabaseResponse>(
                future: DatabaseHelper.fetchUserFromId(listing['user_id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return const Text('Error loading provider');
                  } else if (snapshot.hasData) {
                    return Text(
                      snapshot.data!.data['username'],
                      style: GoogleFonts.mulish(
                        color: Colors.black,
                        fontWeight: FontWeight.w300,
                      ),
                    );
                  } else {
                    return const Text("Error loading provider");
                  }
                },
              ),
            ])));
  }

  List<Widget> _buildListings(BoxConstraints constraints,
      List<Map<String, dynamic>> listings, Map<dynamic, dynamic> categoryMap) {
    return listings
        .map((listing) => InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => Skillinfo(id: listing['id'])),
              );
            },
            child: _skillListing(listing, categoryMap)))
        .expand((element) {
      return [element, const SizedBox(height: 16)];
    }).toList();
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
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load listing'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Failed to load listing'));
          } else {
            final data = snapshot.data as List<dynamic>;
            final listings = data[0] as List<Map<String, dynamic>>;
            final categoryMap = {
              for (var category in data[1]) category['name']: category['asset']
            };
            return LayoutBuilder(
              builder: (context, constraints) {
                return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children:
                        _buildListings(constraints, listings, categoryMap));
              },
            );
          }
        });
  }
}
