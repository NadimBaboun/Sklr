import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/database.dart';
import 'skillinfo.dart';

class CategoryListingsPage extends StatelessWidget{
  final String categoryName;
  const CategoryListingsPage({super.key, required this.categoryName});

  Future<List<Map<String, dynamic>>> fetchCategoryListings() async{
    return await DatabaseHelper.fetchListingsByCategory(categoryName);
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryName,
          style: GoogleFonts.lexend(
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
    body: FutureBuilder<List<Map<String,dynamic>>>(
      future: fetchCategoryListings(),
      builder: (context, snapshot){
        if(snapshot.connectionState == ConnectionState.waiting){
          return const Center(child: CircularProgressIndicator());
        }
        else if(snapshot.hasError){
          return Center(
            child: Text(
              'Error: ${snapshot.error}'
            ),
          );
        }
        else if(!snapshot.hasData ||snapshot.data!.isEmpty){
          return const Center(
            child: Text(
              'No listings found in this category',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final listings = snapshot.data!;
          return ListView.builder(
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () {
                    // Navigate to Skillinfo page with specific skill ID
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Skillinfo(id: listing['id']),
                      ),
                    );
                  },
                child: Card(
                  color: Colors.grey[200],
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          listing['name'] ?? 'No Name',
                          style: GoogleFonts.lexend(
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing['description'] ?? 'No Description',
                          style: GoogleFonts.lexend(
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
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (userSnapshot.hasError) {
                            return const Text(
                              'Error loading user',
                            );
                          } else if (userSnapshot.hasData && userSnapshot.data!.success) {
                            final user = userSnapshot.data!.data;
                            return Text(
                              '${user['username'] ?? 'Unknown User'}',
                              style: GoogleFonts.lexend(
                              color: Colors.black,
                              fontWeight: FontWeight.w200,
                            ),
                              textAlign: TextAlign.center,
                            );
                          } else {
                            return const Text('Unknown User');
                          }
                        },
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}