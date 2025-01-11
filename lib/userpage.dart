import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:sklr/skillinfo.dart';
import 'database/database.dart';
import 'navigationbar-bar.dart';

class UserPage extends StatefulWidget {
  final int userId;

const UserPage({super.key, required this.userId});

@override
_UserPageState createState() => _UserPageState();

}

class _UserPageState extends State<UserPage>{
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState(){
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async{
    try{
      final response = await DatabaseHelper.fetchUserFromId(widget.userId);
      if(response.success){
        setState(() {
          userData = response.data;
          isLoading = false;
        });
      }
      else{
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    }catch(error){
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserListings(int userId) async{
    return await DatabaseHelper.fetchSkills(userId);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

  if (hasError || userData == null) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: const Center(
        child: Text(
          'Error loading user information',
        ),
      ),
    );
  }

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEBFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/avatar.png',
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            userData!['username'] ?? 'Unknown User',
            style: GoogleFonts.lexend(
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${userData!['email'] ?? 'No Email'} | ${userData!['phone_number'] ?? 'No Phone'}',
            style: GoogleFonts.lexend(
              textStyle: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[350],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1)
              ),
              child: Center(
              child: Text(
                userData!['bio'] ?? 'No Bio Available',
                style: GoogleFonts.lexend(
                  textStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              ),
            ),
          const SizedBox(height: 20),
          const Divider(),
          const Text(
            'Listings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchUserListings(widget.userId),
              builder: (context, snapshot) {
                if(snapshot.connectionState == ConnectionState.waiting){
                  return const Center(child: CircularProgressIndicator());
                }
                else if(snapshot.hasError){
                  return Center(child: Text('Error: ${snapshot.hasError}'));
                }
                else if(!snapshot.hasData || snapshot.data!.isEmpty){
                  return const Center(child: Text('No listings found'));
                }

                final listings = snapshot.data!;

                return ListView.builder(
                  itemCount: listings.length,
                  itemBuilder: (context, index){
                    final listing = listings[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: (){
                          Navigator.of(context).push(MaterialPageRoute(builder: (context)=> Skillinfo(id: listing['id']),
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
                                listing['name'] ?? 'No name',
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
                            ],
                          ),
                        ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          )
        ],
      ),
    ),
    bottomNavigationBar: CustomBottomNavigationBar(
      currentIndex: 0),
  );
  }
}