import 'package:flutter/material.dart';
import 'chatsHomePage.dart';
import 'myorderspage.dart';
import 'homepage.dart';
import 'Profile.dart';


class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int loggedInUserId;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.loggedInUserId,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
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
      onTap: (index){
        switch (index){
          case 0: 
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()),
            );
            break;
          case 1:
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> ChatsHomePage()),
            );
            break;
          case 2:
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> MyOrdersPage()),
            );
            break;
          case 3:
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> ProfilePage()),
            );
            break;
        }
      },
      selectedItemColor: const Color(0xFF6296FF),
      unselectedItemColor: Colors.grey,
    );
  }
}