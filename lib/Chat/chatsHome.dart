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
    
    // Initialize user ID first
    _initializeUserId().then((_) {
      _loadChats();
      _loadActiveServices();
      _startPeriodicRefresh();
    });
    
    _animationController.forward();
  }

  // Fetch and store the user ID
  Future<void> _initializeUserId() async {
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        setState(() {
          loggedInUserId = userId is int ? userId : int.tryParse(userId.toString());
        });
        log('Initialized user ID: $loggedInUserId');
      } else {
        log('Warning: No logged in user ID found');
      }
    } catch (e) {
      log('Error initializing user ID: $e');
    }
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
        // Store the user ID for later use
        setState(() {
          loggedInUserId = userId is int ? userId : int.tryParse(userId.toString());
        });
        
        setState(() {
          activeServicesFuture = Future(() async {
            // Directly query for active services from sessions table with joined skill data
            try {
              final response = await supabase
                .from('sessions')
                .select('*, skills(*)')
                .or('requester_id.eq.${loggedInUserId},provider_id.eq.${loggedInUserId}')
                .inFilter('status', ['Requested', 'Pending', 'ReadyForCompletion'])
                .order('updated_at', ascending: false);
              
              if (response == null) return [];
              
              // Process each service to include user names
              final processedServices = await Future.wait(response.map((service) async {
                try {
                  // Get requester data - handle both int and string types for IDs
                  final requesterId = service['requester_id'] is int 
                      ? service['requester_id'] 
                      : int.parse(service['requester_id'].toString());
                      
                  // Get provider data - handle both int and string types for IDs  
                  final providerId = service['provider_id'] is int 
                      ? service['provider_id'] 
                      : int.parse(service['provider_id'].toString());
                      
                  final requesterData = await DatabaseHelper.fetchUserFromId(requesterId);
                  final providerData = await DatabaseHelper.fetchUserFromId(providerId);
                  final skillData = service['skills'] ?? {};
                  
                  return {
                    ...service,
                    'requester_name': requesterData.success ? requesterData.data['username'] : 'Unknown',
                    'provider_name': providerData.success ? providerData.data['username'] : 'Unknown',
                    'skill_name': skillData['name'] ?? 'Unknown Skill',
                    'session_id': service['id'],
                  };
                } catch (e) {
                  log('Error processing service: $e');
                  // Return a minimal service with error indication
                  return {
                    ...service,
                    'requester_name': 'Unknown',
                    'provider_name': 'Unknown',
                    'skill_name': 'Unknown Skill',
                    'session_id': service['id'],
                    'error': true,
                  };
                }
              }));
              return processedServices;
            } catch (e) {
              log('Error loading active services: $e');
              return [];
            }
          });
        });
      } else {
        log('Warning: No logged in user ID for active services');
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
        // Store the user ID for later use
        setState(() {
          loggedInUserId = userId is int ? userId : int.tryParse(userId.toString());
        });
        log('Loading chats for user: $userId');
        
        // Directly query chats from Supabase to ensure fresh data and include the user data
        final response = await supabase
          .from('chats')
          .select('''
            *,
            user1:user1_id (*),
            user2:user2_id (*),
            messages(
              id,
              message,
              sender_id,
              timestamp,
              read
            )
          ''')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('last_updated', ascending: false);
            
        log('Chats response: $response');
        
        if (!mounted) return;
        
        List<Map<String, dynamic>> processedChats = [];
        
        for (var chat in response) {
          try {
            // Extract the other user's data from the joined tables
            final bool isUser1 = chat['user1_id'].toString() == userId.toString();
            final otherUserData = isUser1 ? chat['user2'] : chat['user1'];
            
            if (otherUserData == null) {
              log('Warning: Other user data is null for chat ${chat['id']}');
              continue;
            }
            
            // Extract the last message if available
            String lastMessageText = 'No messages yet';
            String lastMessageTime = '';
            
            // Variable to track if there are unread messages FROM the other user (not sent by current user)
            bool hasUnreadFromOther = false;
            
            if (chat['messages'] != null && chat['messages'].isNotEmpty) {
              // Sort messages by timestamp descending to get the last one
              try {
                chat['messages'].sort((a, b) {
                  if (a['timestamp'] == null && b['timestamp'] == null) return 0;
                  if (a['timestamp'] == null) return 1; // null timestamps at the end
                  if (b['timestamp'] == null) return -1;
                  
                  try {
                    return DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']));
                  } catch (e) {
                    log('Error comparing message timestamps: ${a['timestamp']} vs ${b['timestamp']} - $e');
                    return 0;
                  }
                });
              } catch (e) {
                log('Error sorting messages: $e');
              }
              
              var lastMessage = chat['messages'][0];
              lastMessageText = lastMessage['message'] ?? 'No messages';
              
              // Format the timestamp
              if (lastMessage['timestamp'] != null) {
                try {
                  DateTime timestamp = DateTime.parse(lastMessage['timestamp']);
                  lastMessageTime = _formatMessageTime(timestamp);
                } catch (e) {
                  log('Error parsing message timestamp: ${lastMessage['timestamp']} - $e');
                  lastMessageTime = '';
                }
              }
              
              // Check if there are any unread messages FROM the other user
              hasUnreadFromOther = chat['messages'].any((msg) => 
                !msg['read'] && 
                msg['sender_id'].toString() != userId.toString());
            } else if (chat['last_message'] != null) {
              // Use the cached last_message field if available
              lastMessageText = chat['last_message'];
              
              if (chat['last_updated'] != null) {
                try {
                  DateTime timestamp = DateTime.parse(chat['last_updated']);
                  lastMessageTime = _formatMessageTime(timestamp);
                } catch (e) {
                  log('Error parsing last_updated timestamp: ${chat['last_updated']} - $e');
                  lastMessageTime = '';
                }
              }
            }
            
            processedChats.add({
              'id': chat['id'],
              'user_id': otherUserData['id'],
              'username': otherUserData['username'] ?? 'Unknown User',
              'last_message': lastMessageText,
              'timestamp': lastMessageTime,
              'unread': hasUnreadFromOther, // Only true if there are unread messages FROM the other user
              'avatar_url': otherUserData['avatar_url'],
              'session_id': chat['session_id'],
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

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    
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
      backgroundColor: const Color(0xFFF5F7FF),
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
                        style: GoogleFonts.mulish(
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
                  labelStyle: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.mulish(
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F4FF), Colors.white],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildChatsList(),
            _buildActiveServicesList(),
          ],
        ),
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
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
            ),
          )
        : chats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: GoogleFonts.mulish(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a conversation to see messages here',
                      style: GoogleFonts.mulish(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: chats.length,
                itemBuilder: (context, index) => _buildChatTile(chats[index]),
              );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    // Extract user data
    final String username = chat['username'] ?? 'Unknown User';
    final String lastMessage = chat['last_message'] ?? 'No messages yet';
    final String timestamp = chat['timestamp'] ?? '';
    final bool unread = chat['unread'] ?? false;
    final String? avatarUrl = chat['avatar_url'];
    
    return Dismissible(
      key: Key('chat_${chat['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF5D5D), Color(0xFFFF3A3A)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: GoogleFonts.mulish(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Chat',
                    style: GoogleFonts.mulish(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to delete this chat with $username? This action cannot be undone.',
                style: GoogleFonts.mulish(
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.mulish(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Delete',
                    style: GoogleFonts.mulish(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteChat(chat['id']);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unread 
                ? [const Color(0xFFEDF6FF), const Color(0xFFE1EFFF)]  // Light blue gradient for unread
                : [Colors.white, const Color(0xFFF8F9FF)],  // Subtle white gradient for read
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: unread 
                  ? const Color(0xFF6296FF).withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: unread ? 0 : -2,
            ),
            if (unread) BoxShadow(
              color: const Color(0xFF6296FF).withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
          border: unread
              ? Border.all(color: const Color(0xFF6296FF).withOpacity(0.3), width: 1.5)
              : Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        child: InkWell(
          onTap: () {
            if (loggedInUserId == null) {
              log('Error: No logged in user ID available');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Unable to determine logged in user'))
              );
              return;
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  chatId: chat['id'],
                  loggedInUserId: loggedInUserId!,
                  otherUsername: username,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // User avatar with glow effect for unread messages
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6296FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: unread ? [
                      BoxShadow(
                        color: const Color(0xFF6296FF).withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ] : [],
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: GoogleFonts.mulish(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: unread 
                                  ? const Color(0xFF6296FF)
                                  : const Color(0xFF6296FF).withOpacity(0.7),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Chat details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Username with unread indicator
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    username,
                                    style: GoogleFonts.mulish(
                                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 16,
                                      color: unread ? const Color(0xFF1E1E1E) : Colors.black87,
                                      letterSpacing: unread ? 0.2 : 0,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (unread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6296FF), Color(0xFF458EFE)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6296FF).withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'New',
                                      style: GoogleFonts.mulish(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Timestamp with custom design
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: unread 
                                  ? const Color(0xFF6296FF).withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timestamp,
                              style: GoogleFonts.mulish(
                                color: unread ? const Color(0xFF6296FF) : Colors.grey[600],
                                fontSize: 10,
                                fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Last message preview with better styling
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                        child: Text(
                          lastMessage,
                          style: GoogleFonts.mulish(
                            color: unread ? Colors.black87 : Colors.grey[600],
                            fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
