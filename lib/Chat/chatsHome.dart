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
  Map<int, String> usernameCache = {};
  bool isLoading = false;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> filteredChats = [];
  TextEditingController searchController = TextEditingController();
  bool isSearching = false;
  String selectedCategory = 'All';
  Set<int> pinnedChats = {};
  Set<int> mutedChats = {};

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    // Initialize user ID first
    _initializeUserId().then((_) {
      _loadChats();
      _startPeriodicRefresh();
    });
    
    _animationController.forward();
    _slideController.forward();
    
    searchController.addListener(_filterChats);
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _filterChats() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredChats = _getCategorizedChats();
      } else {
        filteredChats = chats.where((chat) {
          final username = chat['username'].toString().toLowerCase();
          final lastMessage = chat['last_message'].toString().toLowerCase();
          return username.contains(query) || lastMessage.contains(query);
        }).toList();
      }
    });
  }

  List<Map<String, dynamic>> _getCategorizedChats() {
    switch (selectedCategory) {
      case 'Pinned':
        return chats.where((chat) => pinnedChats.contains(chat['id'])).toList();
      case 'Unread':
        return chats.where((chat) => chat['unread'] == true).toList();
      default:
        return chats;
    }
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
        _loadChats(silent: true); // Silent refresh
        _startPeriodicRefresh();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!mounted) return;
    
    if (!silent) {
      setState(() {
        isLoading = true;
      });
    }
    
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        setState(() {
          loggedInUserId = userId is int ? userId : int.tryParse(userId.toString());
        });
        log('Loading chats for user: $userId');
        
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
            final bool isUser1 = chat['user1_id'].toString() == userId.toString();
            final otherUserData = isUser1 ? chat['user2'] : chat['user1'];
            
            if (otherUserData == null) {
              log('Warning: Other user data is null for chat ${chat['id']}');
              continue;
            }
            
            String lastMessageText = 'No messages yet';
            String lastMessageTime = '';
            bool hasUnreadFromOther = false;
            int unreadCount = 0;
            
            if (chat['messages'] != null && chat['messages'].isNotEmpty) {
              try {
                chat['messages'].sort((a, b) {
                  if (a['timestamp'] == null && b['timestamp'] == null) return 0;
                  if (a['timestamp'] == null) return 1;
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
              
              if (lastMessage['timestamp'] != null) {
                try {
                  DateTime timestamp = DateTime.parse(lastMessage['timestamp']);
                  lastMessageTime = _formatMessageTime(timestamp);
                } catch (e) {
                  log('Error parsing message timestamp: ${lastMessage['timestamp']} - $e');
                  lastMessageTime = '';
                }
              }
              
              // Count unread messages
              final unreadMessages = chat['messages'].where((msg) => 
                !msg['read'] && 
                msg['sender_id'].toString() != userId.toString()).toList();
              
              hasUnreadFromOther = unreadMessages.isNotEmpty;
              unreadCount = unreadMessages.length;
            } else if (chat['last_message'] != null) {
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
              'unread': hasUnreadFromOther,
              'unread_count': unreadCount,
              'avatar_url': otherUserData['avatar_url'],
              'session_id': chat['session_id'],
              'is_online': _generateRandomOnlineStatus(),
              'is_typing': false,
              'pinned': pinnedChats.contains(chat['id']),
              'muted': mutedChats.contains(chat['id']),
            });
          } catch (e) {
            log('Error processing chat: $e');
          }
        }
        
        setState(() {
          chats = processedChats;
          filteredChats = _getCategorizedChats();
          if (!silent) isLoading = false;
        });
      }
    } catch (e) {
      log('Error loading chats: $e');
      if (!silent) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _generateRandomOnlineStatus() {
    return DateTime.now().millisecond % 3 == 0;
  }

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][timestamp.weekday - 1];
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _togglePinChat(int chatId) async {
    setState(() {
      if (pinnedChats.contains(chatId)) {
        pinnedChats.remove(chatId);
      } else {
        pinnedChats.add(chatId);
      }
      final chatIndex = chats.indexWhere((chat) => chat['id'] == chatId);
      if (chatIndex != -1) {
        chats[chatIndex]['pinned'] = pinnedChats.contains(chatId);
      }
      _filterChats();
    });
  }

  Future<void> _toggleMuteChat(int chatId) async {
    setState(() {
      if (mutedChats.contains(chatId)) {
        mutedChats.remove(chatId);
      } else {
        mutedChats.add(chatId);
      }
      final chatIndex = chats.indexWhere((chat) => chat['id'] == chatId);
      if (chatIndex != -1) {
        chats[chatIndex]['muted'] = mutedChats.contains(chatId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSearching ? 160 : 120),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2196F3),
                Color(0xFF1976D2),
                Color(0xFF0D47A1),
              ],
            ),
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
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isSearching ? Icons.close_rounded : Icons.search_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  isSearching = !isSearching;
                                  if (!isSearching) {
                                    searchController.clear();
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
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
                    ],
                  ),
                ),
                if (isSearching) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[50]!,
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildCategorySelector(),
                Expanded(child: _buildChatsList()),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildCategorySelector() {
    final categories = ['All', 'Pinned', 'Unread'];
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(
                category,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? Colors.white : const Color(0xFF2196F3),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = category;
                  _filterChats();
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF2196F3),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: const Color(0xFF2196F3).withOpacity(0.3),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatsList() {
    return isLoading
        ? _buildLoadingState()
        : filteredChats.isEmpty
            ? Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2196F3).withOpacity(0.1),
                              const Color(0xFF1976D2).withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        searchController.text.isNotEmpty 
                            ? 'No matching conversations'
                            : selectedCategory == 'All' 
                                ? 'No messages yet'
                                : 'No $selectedCategory chats',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        searchController.text.isNotEmpty 
                            ? 'Try searching with different keywords'
                            : 'Start a conversation to see messages here',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (searchController.text.isEmpty && selectedCategory == 'All') ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to explore users or skills
                          },
                          icon: const Icon(Icons.explore_rounded, size: 20),
                          label: Text(
                            'Find People to Chat',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadChats,
                color: const Color(0xFF2196F3),
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) => _buildEnhancedChatTile(filteredChats[index]),
                ),
              );
  }

  Widget _buildEnhancedChatTile(Map<String, dynamic> chat) {
    final String username = chat['username'] ?? 'Unknown User';
    final String lastMessage = chat['last_message'] ?? 'No messages yet';
    final String timestamp = chat['timestamp'] ?? '';
    final bool unread = chat['unread'] ?? false;
    final int unreadCount = chat['unread_count'] ?? 0;
    final String? avatarUrl = chat['avatar_url'];
    final bool isOnline = chat['is_online'] ?? false;
    final bool isTyping = chat['is_typing'] ?? false;
    final bool isPinned = chat['pinned'] ?? false;
    final bool isMuted = chat['muted'] ?? false;
    
    return Dismissible(
      key: Key('chat_${chat['id']}'),
      background: Container(
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF2196F3).withOpacity(0.8),
              const Color(0xFF1976D2).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isPinned ? 'Unpin' : 'Pin',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _togglePinChat(chat['id']);
          return false;
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unread 
                ? [const Color(0xFFEDF6FF), const Color(0xFFE1EFFF)]
                : [Colors.white, const Color(0xFFF8F9FF)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: unread 
                  ? const Color(0xFF2196F3).withOpacity(0.15)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: unread ? 0 : -2,
            ),
            if (unread) BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
          border: unread
              ? Border.all(color: const Color(0xFF2196F3).withOpacity(0.2), width: 1.5)
              : Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (loggedInUserId == null) {
                log('Error: No logged in user ID available');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error: Unable to determine logged in user',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
            onLongPress: () {
              _showChatOptions(chat);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2196F3).withOpacity(0.1),
                              const Color(0xFF1976D2).withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: unread ? [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.2),
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
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: unread 
                                        ? const Color(0xFF2196F3)
                                        : const Color(0xFF2196F3).withOpacity(0.7),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  if (isPinned) ...[
                                    const Icon(
                                      Icons.push_pin_rounded,
                                      size: 16,
                                      color: Color(0xFF2196F3),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (isMuted) ...[
                                    Icon(
                                      Icons.volume_off_rounded,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      username,
                                      style: GoogleFonts.poppins(
                                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                        fontSize: 16,
                                        color: const Color(0xFF1A1D29),
                                        letterSpacing: unread ? 0.2 : 0,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unreadCount > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2196F3).withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: unread 
                                        ? const Color(0xFF2196F3).withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    timestamp,
                                    style: GoogleFonts.poppins(
                                      color: unread ? const Color(0xFF2196F3) : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTyping ? 'Typing...' : lastMessage,
                          style: GoogleFonts.poppins(
                            color: isTyping 
                                ? const Color(0xFF2196F3)
                                : unread 
                                    ? const Color(0xFF1A1D29) 
                                    : Colors.grey[600],
                            fontWeight: isTyping 
                                ? FontWeight.w600
                                : unread 
                                    ? FontWeight.w500 
                                    : FontWeight.normal,
                            fontSize: 14,
                            height: 1.4,
                            fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
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

  void _showChatOptions(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chat Options',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: chat['pinned'] ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              title: chat['pinned'] ? 'Unpin Chat' : 'Pin Chat',
              onTap: () {
                Navigator.pop(context);
                _togglePinChat(chat['id']);
              },
            ),
            _buildOptionTile(
              icon: chat['muted'] ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              title: chat['muted'] ? 'Unmute Chat' : 'Mute Chat',
              onTap: () {
                Navigator.pop(context);
                _toggleMuteChat(chat['id']);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDestructive 
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red[600] : const Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red[600] : const Color(0xFF1A1D29),
                ),
              ),
            ],
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
              color: const Color(0xFF2196F3).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading chats...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
