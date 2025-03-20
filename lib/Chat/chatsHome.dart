import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database.dart';
import 'chat.dart';
import '../Util/navigationbar-bar.dart';
import '../database/userIdStorage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

final supabase = Supabase.instance.client;

class ChatsHomePage extends StatefulWidget {
  const ChatsHomePage({super.key});

  @override
  _ChatsHomePageState createState() => _ChatsHomePageState();
}

class _ChatsHomePageState extends State<ChatsHomePage> with TickerProviderStateMixin {
  int? loggedInUserId;
  Future<List<Map<String, dynamic>>>? chatsFuture;
  Future<List<Map<String, dynamic>>>? activeServicesFuture;
  Map<int, String> usernameCache = {};
  bool isLoading = false;
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>> chats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadChats();
    _loadActiveServices();
    _startPeriodicRefresh();
    _animationController.forward();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _loadChats();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _loadActiveServices() async {
    if (mounted) {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        setState(() {
          activeServicesFuture = DatabaseHelper.fetchActiveServices().then((services) async {
            // Process each service to include user names
            final processedServices = await Future.wait(services.map((service) async {
              final requesterData = await DatabaseHelper.fetchUserFromId(int.parse(service['requester_id']));
              final providerData = await DatabaseHelper.fetchUserFromId(int.parse(service['provider_id']));
              final skillData = service['skills'] ?? {};
              
              return {
                ...service,
                'requester_name': requesterData.success ? requesterData.data['username'] : 'Unknown',
                'provider_name': providerData.success ? providerData.data['username'] : 'Unknown',
                'skill_name': skillData['name'] ?? 'Unknown Skill',
                'session_id': service['id'],
              };
            }));
            return processedServices;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        log('Loading chats for user: $userId');
        
        // Directly query chats from Supabase to ensure fresh data
        final response = await supabase
          .from('chats')
          .select('''
            *,
            last_message:messages(
              *
            )
          ''')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('updated_at', ascending: false);
            
        log('Chats response: $response');
        
        if (!mounted) return;
        
        List<Map<String, dynamic>> processedChats = [];
        
        for (var chat in response) {
          try {
            // Extract the other user's ID (not the current user)
            final otherUserId = chat['user1_id'] == userId.toString() 
                ? chat['user2_id'] 
                : chat['user1_id'];
            
            // Fetch the other user's details
            final userData = await supabase
                .from('users')
                .select()
                .eq('id', otherUserId)
                .single();
            
            // Extract the last message if available
            String lastMessageText = 'No messages yet';
            String lastMessageTime = '';
            bool unread = false;
            
            if (chat['last_message'] != null && chat['last_message'].isNotEmpty) {
              var lastMessage = chat['last_message'][0];
              lastMessageText = lastMessage['message'] ?? 'No messages';
              
              // Format the timestamp
              if (lastMessage['timestamp'] != null) {
                DateTime timestamp = DateTime.parse(lastMessage['timestamp']);
                lastMessageTime = _formatMessageTime(timestamp);
              }
              
              // Check if message is unread
              unread = !lastMessage['read'] && lastMessage['sender_id'] != userId.toString();
            }
            
            processedChats.add({
              'id': chat['id'],
              'user_id': otherUserId,
              'username': userData['username'] ?? 'Unknown User',
              'last_message': lastMessageText,
              'timestamp': lastMessageTime,
              'unread': unread,
              'avatar_url': userData['avatar_url'],
              'skill_id': chat['skill_id'],
            });
          } catch (e) {
            log('Error processing chat: $e');
          }
        }
        
        setState(() {
          chats = processedChats;
          isLoading = false;
        });
      }
    } catch (e) {
      log('Error loading chats: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      // Format as date if older than a week
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      // Format as day of week if in the last week
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][timestamp.weekday - 1];
    } else {
      // Format as time if today
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _cacheUsernames(List<Map<String, dynamic>> chats) async {
    for (var chat in chats) {
      final otherUserId = chat['user_id'];
      if (!usernameCache.containsKey(otherUserId)) {
        final response = await supabase
          .from('users')
          .select()
          .eq('id', otherUserId)
          .single();
        usernameCache[otherUserId] = response['username'] ?? 'Unknown';
      }
    }
  }

  Future<void> _deleteChat(int chatId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Delete Chat',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this chat? This action cannot be undone.',
            style: GoogleFonts.poppins(
              color: Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await supabase
        .from('chats')
        .delete()
        .eq('id', chatId);
      _loadChats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chat deleted successfully',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6296FF), Color(0xFF4A7BFF)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6296FF).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Messages',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                          onPressed: () {
                            _loadChats();
                            _animationController.reset();
                            _animationController.forward();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Chats'),
                    Tab(text: 'Active Services'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsList(),
          _buildActiveServicesList(),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildActiveServicesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: activeServicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && activeServicesFuture == null) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6296FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    size: 64,
                    color: Color(0xFF6296FF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Active Services',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have no ongoing services at the moment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadActiveServices,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final service = snapshot.data![index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6296FF).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6296FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              color: Color(0xFF6296FF),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['skill_name'] ?? 'Unnamed Service',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Requested by ${service['requester_name']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6296FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Pending',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF6296FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final success = await DatabaseHelper.completeService(service['session_id']);
                                if (success) {
                                  _loadActiveServices();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Service completed successfully',
                                          style: GoogleFonts.poppins(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Complete Service',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final success = await DatabaseHelper.cancelService(service['session_id']);
                                if (success) {
                                  _loadActiveServices();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Service cancelled',
                                          style: GoogleFonts.poppins(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.red[600]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel Service',
                                style: GoogleFonts.poppins(
                                  color: Colors.red[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChatsList() {
    if (isLoading) {
      return _buildLoadingState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.value(chats),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return _buildLoadingState();
          if (snapshot.data!.isEmpty) return _buildEmptyState();

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final chat = snapshot.data![index];
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 400 + (index * 100)),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _buildChatTile(chat),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final otherUserId = chat['user_id'];
    final username = usernameCache[otherUserId] ?? 'Loading...';
    final lastMessage = chat['last_message'] ?? 'No messages yet.';
    final lastUpdated = chat['timestamp'] ?? '';
    final unreadCount = chat['unread'] ? 1 : 0;
    final bool hasUnread = unreadCount > 0;
    final bool isRecent = DateTime.now().difference(
      DateTime.parse(chat['timestamp'] ?? DateTime.now().toString())
    ).inMinutes < 1;
    
    // Determine if this message is a new message received by the user
    final bool isNewMessage = hasUnread && chat['user_id'] != loggedInUserId;

    return Dismissible(
      key: Key('chat_${chat['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 28,
        ),
      ),
      onDismissed: (direction) => _deleteChat(chat['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: isNewMessage 
              ? const Color(0xFF6296FF).withOpacity(0.2)
              : isRecent && hasUnread 
                  ? const Color(0xFF6296FF).withOpacity(0.15)
                  : hasUnread 
                      ? const Color(0xFFEDF4FF) 
                      : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isNewMessage
                  ? const Color(0xFF6296FF).withOpacity(0.4)
                  : isRecent && hasUnread
                      ? const Color(0xFF6296FF).withOpacity(0.3)
                      : hasUnread 
                          ? const Color(0xFF6296FF).withOpacity(0.15)
                          : const Color(0xFF6296FF).withOpacity(0.08),
              blurRadius: isNewMessage ? 30 : isRecent && hasUnread ? 25 : hasUnread ? 20 : 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: hasUnread
              ? Border.all(
                  color: isNewMessage
                      ? const Color(0xFF6296FF).withOpacity(0.7)
                      : isRecent 
                          ? const Color(0xFF6296FF).withOpacity(0.5)
                          : const Color(0xFF6296FF).withOpacity(0.3),
                  width: isNewMessage ? 2.5 : isRecent ? 2 : 1,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  chatId: chat['id'],
                  loggedInUserId: loggedInUserId!,
                  otherUsername: username,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Hero(
                    tag: 'avatar_${chat['id']}',
                    child: Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                isNewMessage 
                                    ? const Color(0xFF4A7BFF)
                                    : const Color(0xFF6296FF),
                                isNewMessage 
                                    ? const Color(0xFF3A6BFF)
                                    : const Color(0xFF4A7BFF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6296FF).withOpacity(isNewMessage ? 0.3 : 0.2),
                                blurRadius: isNewMessage ? 15 : 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              username.isNotEmpty ? username[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isNewMessage 
                                    ? Colors.red
                                    : isRecent 
                                        ? Colors.green 
                                        : const Color(0xFF6296FF),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isNewMessage 
                                        ? Colors.red 
                                        : isRecent 
                                            ? Colors.green 
                                            : const Color(0xFF6296FF)).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                username,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: isNewMessage 
                                      ? FontWeight.w800 
                                      : hasUnread 
                                          ? FontWeight.w700 
                                          : FontWeight.w600,
                                  color: isNewMessage 
                                      ? const Color(0xFF1A1D26) 
                                      : const Color(0xFF1A1D26),
                                ),
                              ),
                            ),
                            Text(
                              lastUpdated,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isNewMessage 
                                    ? Colors.red 
                                    : hasUnread 
                                        ? const Color(0xFF6296FF) 
                                        : Colors.grey[600],
                                fontWeight: isNewMessage 
                                    ? FontWeight.w700 
                                    : hasUnread 
                                        ? FontWeight.w600 
                                        : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isNewMessage 
                                      ? Colors.black 
                                      : hasUnread 
                                          ? const Color(0xFF1A1D26)
                                          : const Color(0xFF88879C),
                                  fontWeight: isNewMessage 
                                      ? FontWeight.w600 
                                      : hasUnread 
                                          ? FontWeight.w500 
                                          : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isNewMessage 
                                      ? Colors.red 
                                      : isRecent 
                                          ? Colors.green 
                                          : const Color(0xFF6296FF),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isNewMessage 
                                          ? Colors.red 
                                          : isRecent 
                                              ? Colors.green 
                                              : const Color(0xFF6296FF)).withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$unreadCount new',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6296FF).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading chats...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF88879C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6296FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Color(0xFF6296FF),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: const Color(0xFF1A1D26),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with someone!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF88879C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
