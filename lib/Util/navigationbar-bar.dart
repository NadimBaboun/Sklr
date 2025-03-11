import 'package:flutter/material.dart';
import '../Chat/chatsHome.dart';
import '../Skills/myOrders.dart';
import '../Home/home.dart';
import '../Profile/profile.dart';
import '../Support/supportMain.dart';
import '../database/database.dart';
import '../database/userIdStorage.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int currentIndex;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
  });

  @override
  State<CustomBottomNavigationBar> createState() => _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  int unreadCount = 0;
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadMessages();
    _loadNotifications();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _loadUnreadMessages();
        _loadNotifications();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final count = await DatabaseHelper.getUnreadMessageCount();
      if (mounted) {
        setState(() {
          unreadCount = count;
        });
      }
    } catch (e) {
      // Handle error silently
      debugPrint('Error loading unread messages: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await DatabaseHelper.getNotifications();
      if (mounted) {
        setState(() {
          notificationCount = notifications.length;
        });
      }
    } catch (e) {
      // Handle error silently
      debugPrint('Error loading notifications: $e');
    }
  }

  Widget _buildBadge(int count) {
    return Positioned(
      right: -8,
      top: -8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(
          minWidth: 18,
          minHeight: 18,
        ),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      currentIndex: widget.currentIndex,
      type: BottomNavigationBarType.fixed,
      items: <BottomNavigationBarItem>[
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.message_outlined),
              if (unreadCount > 0)
                _buildBadge(unreadCount),
            ],
          ),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.list_alt_outlined),
              if (notificationCount > 0)
                _buildBadge(notificationCount),
            ],
          ),
          label: 'My Skills',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.account_circle_outlined),
          label: 'Profile',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.support_agent_outlined),
          activeIcon: Icon(Icons.support_agent),
          label: 'Support',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ChatsHomePage()),
            );
            break;
          case 2:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyOrdersPage()),
            );
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
            break;
          case 4:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SupportMainPage()),
            );
            break;
        }
      },
      selectedItemColor: const Color(0xFF6296FF),
      unselectedItemColor: Colors.grey,
    );
  }
}
