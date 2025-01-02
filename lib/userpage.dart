import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class UserPage extends StatelessWidget {
  final String userName ;
  final String userEmail;
  final String userPhone;

  const UserPage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });


  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            //Avatar section
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
                        child:ClipOval(
                          child: Image.asset(
                            'assets/images/photography.png',
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                          ),
                        )
                      ),
                    )
                  ],
                )
              ],
            ),
          const SizedBox(height: 20),
          Text(
            userName,
            style: GoogleFonts.lexend(
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$userEmail | $userPhone',
            style: GoogleFonts.lexend(
              textStyle: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),
          //Message button
          ElevatedButton.icon(
            onPressed: (){
              //Be directed to a conversation with the user on the message page
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
          const SizedBox(height:20),
          //Rating section
          const Divider(),
          const Text(
            'Rate the Service',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          RatingBar.builder(
            initialRating: 0,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              //Handles the rating and stores in database
            },
          ),
          const Divider(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 2.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.home_outlined,
                color: Color(0xFF6296FF),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              label: 'My Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              label: 'Profile',
            ),
          ],
          selectedItemColor: const Color(0xFF6296FF),
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: UserPage(
      userName: 'Test User',
      userEmail: 'testuser@example.com',
      userPhone: '+01 234 567 89',
    ),
  ));
}