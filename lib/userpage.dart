import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'database/database.dart';

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
          ElevatedButton.icon(
            onPressed: () {
              // To message function
            },
            icon: const Icon(Icons.message, color: Colors.white),
            label: const Text('Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}