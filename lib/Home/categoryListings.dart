import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database.dart';
import '../Skills/skillInfo.dart';
import '../Util/navigationbar-bar.dart';
import '../database/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CategoryListingsPage extends StatefulWidget {
  final String categoryName;
  const CategoryListingsPage({super.key, required this.categoryName});

  @override
  State<CategoryListingsPage> createState() => _CategoryListingsPageState();
}

class _CategoryListingsPageState extends State<CategoryListingsPage> {
  late Future<List<Map<String, dynamic>>> _futureListings;

  @override
  void initState() {
    super.initState();
    _futureListings = _fetchListings();
  }

  Future<List<Map<String, dynamic>>> _fetchListings() async {
    try {
      // Use direct Supabase query to ensure we get the right data
      final listings = await supabase
          .from('skills')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('category', widget.categoryName)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(listings);
    } catch (e) {
      debugPrint('Error fetching category listings: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.categoryName,
          style: GoogleFonts.poppins(
            textStyle: TextStyle(
              fontSize: isLargeScreen ? 28 : 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
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
              bottomLeft: Radius.circular(isLargeScreen ? 28 : 20),
              bottomRight: Radius.circular(isLargeScreen ? 28 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(isLargeScreen ? 28 : 20),
            bottomRight: Radius.circular(isLargeScreen ? 28 : 20),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: _futureListings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: isLargeScreen ? 70 : 60,
                    width: isLargeScreen ? 70 : 60,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                      strokeWidth: 3,
                      backgroundColor: Color(0xFFE0E7FF),
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 24 : 20),
                  Text(
                    'Loading skills...',
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 18 : 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              )
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline, 
                      size: isLargeScreen ? 70 : 60, 
                      color: Colors.red
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 24 : 20),
                  Text(
                    'Oops! Something went wrong',
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 22 : 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 32 : 24),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isLargeScreen ? 16 : 14,
                        color: Colors.red[400],
                      ),
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
                    padding: EdgeInsets.all(isLargeScreen ? 28 : 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_off, 
                      size: isLargeScreen ? 80 : 70, 
                      color: Color(0xFF2196F3)
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 28 : 24),
                  Text(
                    'No listings found',
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 24 : 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  Text(
                    'There are no skills in this category yet',
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 18 : 16,
                      color: const Color(0xFF9094A7),
                    ),
                  ),
                ],
              ),
            );
          }

          final listings = snapshot.data!;
          
          // Responsive Layout Decision
          if (isLargeScreen) {
            // Grid layout for larger screens
            return GridView.builder(
              padding: EdgeInsets.only(
                top: 140, 
                left: isLargeScreen ? 32 : 24, 
                right: isLargeScreen ? 32 : 24, 
                bottom: isLargeScreen ? 32 : 24
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: size.width > 1200 ? 3 : 2,
                childAspectRatio: 1.1,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return _buildResponsiveListingCard(listing, isLargeScreen);
              },
            );
          } else {
            // List layout for smaller screens
            return ListView.builder(
              padding: EdgeInsets.only(
                top: 120, 
                left: 16, 
                right: 16, 
                bottom: 20
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildResponsiveListingCard(listing, isLargeScreen),
                );
              },
            );
          }
        },
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildResponsiveListingCard(Map<String, dynamic> listing, bool isLargeScreen) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.08),
            blurRadius: isLargeScreen ? 25 : 20,
            offset: Offset(0, isLargeScreen ? 10 : 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
        child: InkWell(
          borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => Skillinfo(id: listing['id']),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(isLargeScreen ? 28 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        listing['name'] ?? 'No Name',
                        style: GoogleFonts.poppins(
                          fontSize: isLargeScreen ? 22 : 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2D3142),
                          letterSpacing: -0.5,
                        ),
                        maxLines: isLargeScreen ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: isLargeScreen ? 16 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 18 : 14, 
                        vertical: isLargeScreen ? 10 : 8
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2196F3),
                            const Color(0xFF1976D2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(isLargeScreen ? 32 : 30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '${listing['cost'] ?? '0'} credits',
                        style: GoogleFonts.poppins(
                          fontSize: isLargeScreen ? 18 : 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isLargeScreen ? 16 : 12),
                Container(
                  padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 12 : 10),
                  child: Text(
                    listing['description'] ?? 'No Description',
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 17 : 15,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    maxLines: isLargeScreen ? 4 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Divider(
                  color: Color(0xFFEEF2FF), 
                  thickness: isLargeScreen ? 2 : 1.5
                ),
                SizedBox(height: isLargeScreen ? 16 : 12),
                FutureBuilder<DatabaseResponse>(
                  future: DatabaseHelper.fetchUserFromId(listing['user_id']),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: SizedBox(
                          height: isLargeScreen ? 28 : 24,
                          width: isLargeScreen ? 28 : 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                          ),
                        ),
                      );
                    } else if (userSnapshot.hasData && userSnapshot.data!.success) {
                      final user = userSnapshot.data!.data;
                      return Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF2196F3).withOpacity(0.1),
                                  const Color(0xFF1976D2).withOpacity(0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: isLargeScreen ? 24 : 20,
                              backgroundColor: Colors.transparent,
                              child: Text(
                                (user['username'] ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF2196F3),
                                  fontWeight: FontWeight.w600,
                                  fontSize: isLargeScreen ? 18 : 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isLargeScreen ? 16 : 12),
                          Expanded(
                            child: Text(
                              user['username'] ?? 'Unknown User',
                              style: GoogleFonts.poppins(
                                fontSize: isLargeScreen ? 17 : 15,
                                color: const Color(0xFF2D3142),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 14 : 10, 
                              vertical: isLargeScreen ? 8 : 6
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E6),
                              borderRadius: BorderRadius.circular(isLargeScreen ? 24 : 20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: isLargeScreen ? 20 : 18,
                                  color: Color(0xFFFFC107),
                                ),
                                SizedBox(width: isLargeScreen ? 6 : 4),
                                Text(
                                  '${(user['rating'] ?? 0.0).toStringAsFixed(1)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: isLargeScreen ? 16 : 14,
                                    color: const Color(0xFF2D3142),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Container(
                        padding: EdgeInsets.all(isLargeScreen ? 14 : 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(isLargeScreen ? 14 : 10),
                        ),
                        child: Text(
                          'Unknown User',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: isLargeScreen ? 16 : 14,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
