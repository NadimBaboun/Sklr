import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database.dart';
import '../Skills/skillInfo.dart';
import '../Util/navigationbar-bar.dart';

class CategoryListingsPage extends StatelessWidget {
  final String categoryName;
  const CategoryListingsPage({super.key, required this.categoryName});

  Future<List<Map<String, dynamic>>> fetchCategoryListings() async {
    return await DatabaseHelper.fetchListingsByCategory(categoryName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          categoryName,
          style: GoogleFonts.mulish(
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white
            ),
          ),
        ),
        backgroundColor: const Color(0xFF6296FF),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: fetchCategoryListings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
              )
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.mulish(
                      fontSize: 16,
                      color: Colors.red[700]
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
                  const Icon(Icons.search_off, size: 60, color: Color(0xFF9094A7)),
                  const SizedBox(height: 16),
                  Text(
                    'No listings found in this category',
                    style: GoogleFonts.mulish(
                      fontSize: 18,
                      color: const Color(0xFF9094A7)
                    ),
                  ),
                ],
              ),
            );
          }

          final listings = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Skillinfo(id: listing['id']),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                listing['name'] ?? 'No Name',
                                style: GoogleFonts.mulish(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2D3142),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6296FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '\$${listing['price'] ?? '0'}',
                                style: GoogleFonts.mulish(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          listing['description'] ?? 'No Description',
                          style: GoogleFonts.mulish(
                            fontSize: 15,
                            color: const Color(0xFF9094A7),
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<DatabaseResponse>(
                          future: DatabaseHelper.fetchUserFromId(listing['user_id']),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
                                ),
                              );
                            } else if (userSnapshot.hasData && userSnapshot.data!.success) {
                              final user = userSnapshot.data!.data;
                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF6296FF).withOpacity(0.1),
                                    child: Text(
                                      (user['username'] ?? 'U')[0].toUpperCase(),
                                      style: GoogleFonts.mulish(
                                        color: const Color(0xFF6296FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user['username'] ?? 'Unknown User',
                                    style: GoogleFonts.mulish(
                                      fontSize: 15,
                                      color: const Color(0xFF2D3142),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.star,
                                    size: 18,
                                    color: Color(0xFFFFC107),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(user['rating'] ?? 0.0).toStringAsFixed(1)}',
                                    style: GoogleFonts.mulish(
                                      fontSize: 15,
                                      color: const Color(0xFF2D3142),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Text(
                                'Unknown User',
                                style: GoogleFonts.mulish(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 0),
    );
  }
}