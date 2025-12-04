import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database.dart';
import 'chat.dart';
import '../Util/navigation-bar.dart';
import '../database/user_id_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import '../database/supabase_service.dart';
import '../database/presence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final supabase = Supabase.instance.client;

class ChatsHomePage extends StatefulWidget {
  final int? initialTabIndex; // Tab index to show when page loads
  
  const ChatsHomePage({super.key, this.initialTabIndex});

  @override
  ChatsHomePageState createState() => ChatsHomePageState();
}

class ChatsHomePageState extends State<ChatsHomePage> with TickerProviderStateMixin {
  int? loggedInUserId;
  Future<List<Map<String, dynamic>>>? chatsFuture;
  Future<List<Map<String, dynamic>>>? activeServicesFuture;
  Future<List<Map<String, dynamic>>>? servicesReceivedFuture; // Services being provided TO you
  Map<int, String> usernameCache = {};
  bool isLoading = false;
  late TabController _tabController;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _refreshAnimationController;
  Set<String> _onlineUserKeys = {};
  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> filteredChats = [];
  List<Map<String, dynamic>> requesterChats = []; // Chats where user is requester (receiving service)
  List<Map<String, dynamic>> providerChats = []; // Chats where user is provider (providing service)
  TextEditingController searchController = TextEditingController();
  bool isSearching = false;
  String selectedCategory = 'All';
  Set<int> pinnedChats = {};
  Set<int> deletedChatIds = {}; // Locally stored deleted chat IDs
  int lastUnreadCount = 0;
  final Map<int, AnimationController> _chatAnimationControllers = {};
  final Map<int, AnimationController> _serviceAnimationControllers = {};
  Map<int, int> _chatMessageCounts = {};
  final Map<int, String> _serviceStatuses = {};
  final Map<int, Map<String, dynamic>> _sessionDetailsCache = {};
  final Map<int, String> _lastKnownSessionStatus = {}; // Track last known status per session to detect changes
  Map<String, dynamic>? _currentChatGroup; // Currently displayed chat group detail
  bool _showChatGroupDetail = false; // Whether to show chat group detail view
  int? _previousTabIndex; // Track which tab user was on before opening a chat
  bool _wasInGroupView = false; // Track if we were in group detail view before opening a chat
  Map<String, dynamic>? _previousChatGroup; // Store the group we were viewing before opening a chat

  String _deletedChatsStorageKey(dynamic userId) => 'deleted_chat_ids_user_${userId.toString()}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAnimations();
    
    // Set initial tab index if provided (when returning from chat)
    if (widget.initialTabIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != widget.initialTabIndex) {
          _tabController.animateTo(widget.initialTabIndex!);
        }
      });
    }
    
    // Initialize user ID first
    _initializeUserId().then((_) {
      _loadDeletedChatIds().then((_) {
        _loadChats(); // Load actual chats from the chats table
        _loadServicesReceived(); // Services being provided TO you (for Chats tab)
        _loadActiveServices(); // Services you are PROVIDING (for Services tab)
        _setupPresenceChannel();
        _startPeriodicRefresh();
      });
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

    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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

  String? _normalizeUserKey(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  bool _isUserOnline(dynamic userId) {
    final key = _normalizeUserKey(userId);
    if (key == null) return false;
    return _onlineUserKeys.contains(key);
  }

  void _onPresenceUpdate(Set<String> onlineKeys) {
    if (mounted) {
      setState(() {
        _onlineUserKeys = onlineKeys;
      });
    } else {
      _onlineUserKeys = onlineKeys;
    }
  }

  Future<void> _setupPresenceChannel() async {
    final currentUserId = loggedInUserId;
    if (currentUserId == null) {
      return;
    }
    try {
      // Ensure the current user is tracked globally via PresenceService
      // This ensures they show as online regardless of which page they're on
      await PresenceService.ensureTrackingStarted();
      
      // Subscribe to presence updates from the global PresenceService
      // This avoids creating a conflicting channel subscription
      PresenceService.addPresenceListener(_onPresenceUpdate);
      
      // Get initial state
      _onlineUserKeys = PresenceService.getOnlineUserKeys();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      log('Error setting up presence tracking: $e');
    }
  }

  Future<void> _teardownPresenceChannel() async {
    // Remove our listener from PresenceService
    // This doesn't affect the global tracking, just stops receiving updates
    PresenceService.removePresenceListener(_onPresenceUpdate);

    if (mounted) {
      setState(() {
        _onlineUserKeys.clear();
      });
    } else {
      _onlineUserKeys.clear();
    }
  }

  Widget _buildOnlineIndicatorDot({
    double size = 16,
    double borderWidth = 2,
    Color borderColor = Colors.white,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSearchFilteredChats(String query) {
    if (query.isEmpty) {
      return _getCategorizedChats();
    }

    return requesterChats.where((chat) {
      final username = (chat['username'] ?? '').toString().toLowerCase();
      final lastMessage = (chat['last_message'] ?? '').toString().toLowerCase();
      final List<dynamic> chatSessions = (chat['chat_sessions'] as List<dynamic>? ?? []);
      final bool sessionMatch = chatSessions.any((session) {
        if (session is! Map<String, dynamic>) return false;
        final sessionId = session['session_id'];
        final skillName = sessionId != null
            ? (_sessionDetailsCache[sessionId]?['skills']?['name'] ?? '').toString().toLowerCase()
            : '';
        final serviceMessage = (session['last_message'] ?? '').toString().toLowerCase();
        return skillName.contains(query) || serviceMessage.contains(query);
      });
      return username.contains(query) || lastMessage.contains(query) || sessionMatch;
    }).toList();
  }

  void _filterChats() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredChats = _getSearchFilteredChats(query);
    });
  }

  List<Map<String, dynamic>> _getCategorizedChats() {
    // Return filtered requester chats for the Chats tab
    switch (selectedCategory) {
      case 'Pinned':
        return requesterChats.where((chat) => chat['pinned'] == true).toList();
      case 'Unread':
        return requesterChats.where((chat) => chat['unread'] == true).toList();
      default:
        return requesterChats;
    }
  }

  int? _normalizeChatIdValue(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value != null) {
      return int.tryParse(value.toString());
    }
    return null;
  }

  bool _removeChatFromList(List<Map<String, dynamic>> list, int chatId) {
    bool listChanged = false;
    for (int i = list.length - 1; i >= 0; i--) {
      final chat = list[i];
      final aggregatedChatId = _normalizeChatIdValue(chat['id']);

      // If the aggregated chat itself matches the chat ID (unlikely but safe), remove it entirely
      if (aggregatedChatId == chatId) {
        list.removeAt(i);
        listChanged = true;
        continue;
      }

      final List<Map<String, dynamic>> sessions =
          (chat['chat_sessions'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      if (sessions.isEmpty) continue;

      final filteredSessions = sessions.where((session) {
        final sessionChatId = _normalizeChatIdValue(session['id']);
        return sessionChatId != chatId;
      }).toList();

      if (filteredSessions.length != sessions.length) {
        listChanged = true;
        if (filteredSessions.isEmpty) {
          list.removeAt(i);
        } else {
          chat['chat_sessions'] = filteredSessions;
          chat['has_multiple'] = filteredSessions.length > 1;
          final topSession = filteredSessions.first;
          chat['last_message'] = topSession['last_message'];
          chat['timestamp'] = topSession['timestamp'];
          chat['last_updated'] = topSession['last_updated'];
          final totalUnread = filteredSessions.fold<int>(
            0,
            (sum, session) => sum + _parseUnreadCountValue(session['unread_count']),
          );
          chat['unread_count'] = totalUnread;
          chat['unread'] = totalUnread > 0;
        }
      }
    }
    return listChanged;
  }

  void _updateCurrentGroupAfterDeletion(int chatId) {
    if (_currentChatGroup == null) return;
    final List<Map<String, dynamic>> sessions =
        (_currentChatGroup!['chat_sessions'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    if (sessions.isEmpty) return;

    final filteredSessions = sessions.where((session) {
      final sessionChatId = _normalizeChatIdValue(session['id']);
      return sessionChatId != chatId;
    }).toList();

    if (filteredSessions.length == sessions.length) return;

    if (filteredSessions.isEmpty) {
      _currentChatGroup = null;
      _showChatGroupDetail = false;
    } else {
      _currentChatGroup!['chat_sessions'] = filteredSessions;
      _currentChatGroup!['has_multiple'] = filteredSessions.length > 1;
      final totalUnread = filteredSessions.fold<int>(
        0,
        (sum, session) => sum + _parseUnreadCountValue(session['unread_count']),
      );
      _currentChatGroup!['unread_count'] = totalUnread;
      _currentChatGroup!['unread'] = totalUnread > 0;
    }
  }

  void _removeChatFromState(int chatId) {
    bool didChange = false;
    setState(() {
      final changedMain = _removeChatFromList(chats, chatId);
      final changedRequester = _removeChatFromList(requesterChats, chatId);
      final changedProvider = _removeChatFromList(providerChats, chatId);
      didChange = changedMain || changedRequester || changedProvider;
      filteredChats = _getSearchFilteredChats(searchController.text.toLowerCase());
      if (didChange) {
        _updateCurrentGroupAfterDeletion(chatId);
      }
    });
  }

  // Fetch and store the user ID
  Future<void> _loadDeletedChatIds() async {
    try {
      final userId = loggedInUserId ?? await UserIdStorage.getLoggedInUserId();
      if (userId == null) {
        deletedChatIds = {};
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final List<String>? deletedIds = prefs.getStringList(_deletedChatsStorageKey(userId));
      if (deletedIds != null) {
        deletedChatIds = deletedIds.map((id) => int.tryParse(id)).whereType<int>().toSet();
      } else {
        deletedChatIds = {};
      }
    } catch (e) {
      log('Error loading deleted chat IDs: $e');
      deletedChatIds = {};
    }
  }

  Future<void> _saveDeletedChatIds() async {
    try {
      final userId = loggedInUserId ?? await UserIdStorage.getLoggedInUserId();
      if (userId == null) return;
      final prefs = await SharedPreferences.getInstance();
      final List<String> deletedIds = deletedChatIds.map((id) => id.toString()).toList();
      await prefs.setStringList(_deletedChatsStorageKey(userId), deletedIds);
    } catch (e) {
      log('Error saving deleted chat IDs: $e');
    }
  }

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
    Future.delayed(const Duration(seconds: 10), () async {
      if (mounted) {
        try {
          final newUnreadCount = await SupabaseService.getUnreadMessageCount();
          if (newUnreadCount != lastUnreadCount) {
            _loadChats();
            setState(() {
              lastUnreadCount = newUnreadCount;
            });
          }
        } catch (e) {
          debugPrint('Error checking unread messages: $e');
        }
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _loadServicesReceived() async {
    // Services being provided TO you (you are the requester)
    if (!mounted) return;
    
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        setState(() {
          loggedInUserId = userId is int ? userId : int.tryParse(userId.toString());
        });
        
        final response = await supabase
          .from('sessions')
          .select('*, skills(*)')
          .eq('requester_id', loggedInUserId!)
          .inFilter('status', ['Requested', 'Pending', 'ReadyForCompletion'])
          .order('updated_at', ascending: false);
        
        final processedServices = await Future.wait(response.map((service) async {
          try {
            final providerId = service['provider_id'] is int 
                ? service['provider_id'] 
                : int.parse(service['provider_id'].toString());
                
            final providerData = await DatabaseHelper.fetchUserFromId(providerId);
            final skillData = service['skills'] ?? {};
            
            final serviceId = service['id'];
            final newStatus = service['status'];
            
            // Create animation controller for new services
            if (!_serviceAnimationControllers.containsKey(serviceId)) {
              _serviceAnimationControllers[serviceId] = AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 500),
              )..value = 1.0;
            }
            
            // Check if this service status has changed
            if (_serviceStatuses.containsKey(serviceId) && 
                _serviceStatuses[serviceId] != newStatus) {
              // Trigger refresh animation for this service
              _serviceAnimationControllers[serviceId]!.reverse();
              await _serviceAnimationControllers[serviceId]!.forward();
            }
            
            // Update the status
            _serviceStatuses[serviceId] = newStatus;
            
            return {
              ...service,
              'provider_name': providerData.success ? providerData.data['username'] : 'Unknown',
              'provider_id': providerId,
              'skill_name': skillData['name'] ?? 'Unknown Skill',
              'session_id': serviceId,
            };
          } catch (e) {
            log('Error processing service: $e');
            return {
              ...service,
              'provider_name': 'Unknown',
              'skill_name': 'Unknown Skill',
              'session_id': service['id'],
              'error': true,
            };
          }
        }));
        
        // Group services by provider (similar to chat grouping)
        final Map<int, List<Map<String, dynamic>>> groupedServices = {};
        for (final service in processedServices) {
          final providerId = service['provider_id'];
          if (providerId != null) {
            final providerIdInt = providerId is int ? providerId : int.tryParse(providerId.toString());
            if (providerIdInt != null) {
              groupedServices.putIfAbsent(providerIdInt, () => []).add(service);
            }
          }
        }
        
        final List<Map<String, dynamic>> aggregatedServices = [];
        groupedServices.forEach((providerKey, providerServices) {
          providerServices.sort((a, b) {
            final bTime = _parseDateTime(b['updated_at']);
            final aTime = _parseDateTime(a['updated_at']);
            return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
          });
          final topService = providerServices.isNotEmpty ? providerServices.first : null;
          if (topService == null) return;
          
          aggregatedServices.add({
            'id': providerKey,
            'provider_id': providerKey,
            'provider_name': topService['provider_name'] ?? 'Unknown',
            'skill_name': topService['skill_name'] ?? 'Unknown Skill',
            'status': topService['status'] ?? 'Pending',
            'services': providerServices,
            'has_multiple': providerServices.length > 1,
            'last_updated': topService['updated_at'],
          });
        });
        
        aggregatedServices.sort((a, b) {
          final bTime = _parseDateTime(b['last_updated']);
          final aTime = _parseDateTime(a['last_updated']);
          return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
        
        if (mounted) {
          setState(() {
            servicesReceivedFuture = Future.value(aggregatedServices);
          });
        }
      }
    } catch (e) {
      log('Error loading services received: $e');
    }
  }

  Future<void> _loadActiveServices() async {
    // Services you are PROVIDING (you are the provider)
    if (!mounted) return;
    
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        setState(() {
          loggedInUserId = userId is int ? userId : int.tryParse(userId.toString());
        });
        
        final response = await supabase
          .from('sessions')
          .select('*, skills(*)')
          .eq('provider_id', loggedInUserId!)
          .inFilter('status', ['Requested', 'Pending', 'ReadyForCompletion'])
          .order('updated_at', ascending: false);
        
        final processedServices = await Future.wait(response.map((service) async {
          try {
            final requesterId = service['requester_id'] is int 
                ? service['requester_id'] 
                : int.parse(service['requester_id'].toString());
                
            final requesterData = await DatabaseHelper.fetchUserFromId(requesterId);
            final skillData = service['skills'] ?? {};
            
            final serviceId = service['id'];
            final newStatus = service['status'];
            
            // Create animation controller for new services
            if (!_serviceAnimationControllers.containsKey(serviceId)) {
              _serviceAnimationControllers[serviceId] = AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 500),
              )..value = 1.0;
            }
            
            // Check if this service status has changed
            if (_serviceStatuses.containsKey(serviceId) && 
                _serviceStatuses[serviceId] != newStatus) {
              // Trigger refresh animation for this service
              _serviceAnimationControllers[serviceId]!.reverse();
              await _serviceAnimationControllers[serviceId]!.forward();
            }
            
            // Update the status
            _serviceStatuses[serviceId] = newStatus;
            
            return {
              ...service,
              'requester_name': requesterData.success ? requesterData.data['username'] : 'Unknown',
              'requester_id': requesterId,
              'skill_name': skillData['name'] ?? 'Unknown Skill',
              'session_id': serviceId,
            };
          } catch (e) {
            log('Error processing service: $e');
            return {
              ...service,
              'requester_name': 'Unknown',
              'skill_name': 'Unknown Skill',
              'session_id': service['id'],
              'error': true,
            };
          }
        }));
        
        // Group services by requester (similar to chat grouping)
        final Map<int, List<Map<String, dynamic>>> groupedServices = {};
        for (final service in processedServices) {
          final requesterId = service['requester_id'];
          if (requesterId != null) {
            final requesterIdInt = requesterId is int ? requesterId : int.tryParse(requesterId.toString());
            if (requesterIdInt != null) {
              groupedServices.putIfAbsent(requesterIdInt, () => []).add(service);
            }
          }
        }
        
        final List<Map<String, dynamic>> aggregatedServices = [];
        groupedServices.forEach((requesterKey, requesterServices) {
          requesterServices.sort((a, b) {
            final bTime = _parseDateTime(b['updated_at']);
            final aTime = _parseDateTime(a['updated_at']);
            return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
          });
          final topService = requesterServices.isNotEmpty ? requesterServices.first : null;
          if (topService == null) return;
          
          aggregatedServices.add({
            'id': requesterKey,
            'requester_id': requesterKey,
            'requester_name': topService['requester_name'] ?? 'Unknown',
            'skill_name': topService['skill_name'] ?? 'Unknown Skill',
            'status': topService['status'] ?? 'Pending',
            'services': requesterServices,
            'has_multiple': requesterServices.length > 1,
            'last_updated': topService['updated_at'],
          });
        });
        
        aggregatedServices.sort((a, b) {
          final bTime = _parseDateTime(b['last_updated']);
          final aTime = _parseDateTime(a['last_updated']);
          return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
        
        if (mounted) {
          setState(() {
            activeServicesFuture = Future.value(aggregatedServices);
          });
        }
      }
    } catch (e) {
      log('Error loading active services: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    _refreshAnimationController.dispose();
    // Dispose all chat-specific animation controllers
    for (var controller in _chatAnimationControllers.values) {
      controller.dispose();
    }
    // Dispose all service-specific animation controllers
    for (var controller in _serviceAnimationControllers.values) {
      controller.dispose();
    }
    searchController.dispose();
    _teardownPresenceChannel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    if (!mounted) return;
    
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        final parsedUserId = userId is int ? userId : int.tryParse(userId.toString());
        setState(() {
          loggedInUserId = parsedUserId;
          isLoading = true;
        });

        // Ensure presence tracking is set up
        if (parsedUserId != null) {
          _setupPresenceChannel();
        }
        
        final response = await supabase
          .from('chats')
          .select('''
            *,
            user1:user1_id (*),
            user2:user2_id (*),
            sessions(
              id,
              provider_id,
              requester_id,
              status
            ),
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
            
        if (!mounted) return;
        
        List<Map<String, dynamic>> processedChats = [];
        Map<int, int> newMessageCounts = {};
        
        for (var chat in response) {
          try {
            final chatId = chat['id'];
            
            // Skip chats that have been deleted locally
            if (chatId != null && deletedChatIds.contains(chatId)) {
              continue;
            }
            
            final bool isUser1 = chat['user1_id'].toString() == userId.toString();
            final otherUserData = isUser1 ? chat['user2'] : chat['user1'];
            final otherUserIdRaw = otherUserData?['id'];
            int? otherUserId;
            if (otherUserIdRaw is int) {
              otherUserId = otherUserIdRaw;
            } else if (otherUserIdRaw is String) {
              otherUserId = int.tryParse(otherUserIdRaw);
            }
            
            if (otherUserData == null) {
              log('Warning: Other user data is null for chat ${chat['id']}');
              continue;
            }
            
            String lastMessageText = 'No messages yet';
            String lastMessageTime = '';
            bool hasUnreadFromOther = false;
            int unreadCount = 0;
            int totalMessages = 0;
            
            if (chat['messages'] != null && chat['messages'].isNotEmpty) {
              totalMessages = chat['messages'].length;
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
              
              final unreadMessages = chat['messages'].where((msg) => 
                !msg['read'] && 
                msg['sender_id'].toString() != userId.toString()).toList();
              
              hasUnreadFromOther = unreadMessages.isNotEmpty;
              unreadCount = unreadMessages.length;
            }
            
            newMessageCounts[chatId] = totalMessages;
            
            // Create animation controller for new chats
            if (!_chatAnimationControllers.containsKey(chatId)) {
              _chatAnimationControllers[chatId] = AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 500),
              )..value = 1.0;
            }
            
            // Check if this chat has new messages
            if (_chatMessageCounts.containsKey(chatId) && 
                _chatMessageCounts[chatId]! < totalMessages) {
              // Trigger refresh animation for this chat
              _chatAnimationControllers[chatId]!.reverse();
              await _chatAnimationControllers[chatId]!.forward();
            }
            
            // Determine if user is provider or requester
            bool isRequester = false;
            bool isProvider = false;
            Map<String, dynamic>? sessionData;
            String? currentSessionStatus;
            int? sessionId;
            bool hasStatusChange = false;
            
            if (chat['sessions'] != null) {
              if (chat['sessions'] is List && (chat['sessions'] as List).isNotEmpty) {
                sessionData = (chat['sessions'] as List)[0] as Map<String, dynamic>?;
              } else if (chat['sessions'] is Map<String, dynamic>) {
                sessionData = chat['sessions'] as Map<String, dynamic>;
              }
              
              if (sessionData != null) {
                final providerId = sessionData['provider_id'];
                final requesterId = sessionData['requester_id'];
                isRequester = requesterId?.toString() == userId.toString();
                isProvider = providerId?.toString() == userId.toString();
                
                // Get current session status
                sessionId = sessionData['id'] is int ? sessionData['id'] as int : int.tryParse(sessionData['id']?.toString() ?? '');
                currentSessionStatus = sessionData['status']?.toString();
                
                // Check if status has changed (if we've seen this session before)
                if (sessionId != null && currentSessionStatus != null) {
                  final lastKnownStatus = _lastKnownSessionStatus[sessionId];
                  
                  // Check if this is a new service request (status is "Requested" and we haven't seen it)
                  // OR if status has changed from what we last saw
                  bool shouldMarkAsUnread = false;
                  
                  if (currentSessionStatus == 'Requested') {
                    // Service request - mark as unread for provider if we haven't seen this status yet
                    if (isProvider) {
                      if (lastKnownStatus == null || lastKnownStatus != 'Requested') {
                        // New request or status changed to Requested - mark as unread
                        shouldMarkAsUnread = true;
                      }
                    }
                  } else if (lastKnownStatus != null && lastKnownStatus != currentSessionStatus) {
                    // Status has changed to something other than Requested - mark as unread
                    shouldMarkAsUnread = true;
                  }
                  
                  if (shouldMarkAsUnread) {
                    hasStatusChange = true;
                    if (!hasUnreadFromOther) {
                      hasUnreadFromOther = true;
                    }
                    unreadCount += 1; // Add 1 for status change
                  }
                  
                  // Update last known status when user views the chat (handled in _openChatSession)
                  // Always update the last known status so that when user opens the chat,
                  // the status change is marked as seen and won't count as unread anymore
                  // This ensures that reviewing a request (opening the chat) removes the unread badge
                  // Note: The actual update happens in _openChatSession when the chat is opened
                }
              }
            }
            
            processedChats.add({
              'id': chatId,
              'user_id': otherUserData['id'],
              'other_user_id': otherUserId ?? otherUserData['id'],
              'username': otherUserData['username'] ?? 'Unknown User',
              'last_message': lastMessageText,
              'timestamp': lastMessageTime,
              'unread': hasUnreadFromOther,
              'unread_count': unreadCount,
              'avatar_url': otherUserData['avatar_url'],
              'session_id': chat['session_id'] ?? sessionId,
              'is_typing': false,
              'pinned': pinnedChats.contains(chatId),
              'total_messages': totalMessages,
              'last_updated': chat['last_updated'],
              'is_requester': isRequester,
              'is_provider': isProvider,
              'has_status_change': hasStatusChange,
            });
          } catch (e) {
            log('Error processing chat: $e');
          }
        }
        
        final missingSessionIds = processedChats
            .map((chat) => chat['session_id'])
            .whereType<int>()
            .where((sessionId) => !_sessionDetailsCache.containsKey(sessionId))
            .toSet()
            .toList();

        await _fetchSessionDetails(missingSessionIds);

        // Group chats by both other_user_id AND role (provider/requester)
        // This ensures chats with the same user are separated if roles differ
        final Map<String, List<Map<String, dynamic>>> groupedChats = {};
        for (final chat in processedChats) {
          final otherUserIdDynamic = chat['other_user_id'];
          int? otherUserIdInt;
          if (otherUserIdDynamic is int) {
            otherUserIdInt = otherUserIdDynamic;
          } else if (otherUserIdDynamic is String) {
            otherUserIdInt = int.tryParse(otherUserIdDynamic);
          }
          if (otherUserIdInt != null) {
            // Create a composite key: user_id + role
            // This separates provider chats from requester chats even with same user
            final bool isRequester = chat['is_requester'] == true;
            final bool isProvider = chat['is_provider'] == true;
            String groupKey;
            if (isProvider) {
              groupKey = '${otherUserIdInt}_provider';
            } else if (isRequester) {
              groupKey = '${otherUserIdInt}_requester';
            } else {
              // Fallback for chats without clear role (shouldn't happen, but handle it)
              groupKey = '${otherUserIdInt}_unknown';
            }
            groupedChats.putIfAbsent(groupKey, () => []).add(chat);
          }
        }

        final List<Map<String, dynamic>> aggregatedChats = [];
        groupedChats.forEach((groupKey, userChats) {
          userChats.sort((a, b) {
            final bTime = _parseDateTime(b['last_updated']);
            final aTime = _parseDateTime(a['last_updated']);
            return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
          });
          final topChat = userChats.isNotEmpty ? userChats.first : null;
          if (topChat == null) return;

          final int totalUnreadCount = userChats.fold<int>(0, (sum, chatItem) {
            final unreadValue = chatItem['unread_count'];
            if (unreadValue is int) return sum + unreadValue;
            if (unreadValue is String) return sum + (int.tryParse(unreadValue) ?? 0);
            return sum;
          });

          final bool isPinnedGroup = userChats.any((chatItem) => pinnedChats.contains(chatItem['id']));
          final bool isTypingGroup = userChats.any((chatItem) => chatItem['is_typing'] == true);
          final bool hasMultiple = userChats.length > 1;
          final List<int> sessionIds = userChats
              .map((chatItem) {
                final sessionId = chatItem['session_id'];
                if (sessionId is int) return sessionId;
                if (sessionId is String) return int.tryParse(sessionId);
                return null;
              })
              .whereType<int>()
              .toList();

          // Determine if this aggregated chat is for requester or provider
          // If any chat in the group is requester/provider, the whole group is
          final bool isRequesterGroup = userChats.any((chatItem) => chatItem['is_requester'] == true);
          final bool isProviderGroup = userChats.any((chatItem) => chatItem['is_provider'] == true);
          
          // Extract user ID from the group key (format: "userId_provider" or "userId_requester")
          final int? extractedUserId = topChat['other_user_id'] is int 
              ? topChat['other_user_id'] as int
              : int.tryParse((topChat['other_user_id'] ?? '').toString());
          
          // Use groupKey hash as unique ID to avoid collisions between provider/requester groups with same user
          final int uniqueGroupId = groupKey.hashCode;
          
          final aggregatedChat = {
            'id': uniqueGroupId,
            'user_id': extractedUserId ?? 0,
            'username': topChat['username'],
            'last_message': topChat['last_message'],
            'timestamp': topChat['timestamp'],
            'unread': totalUnreadCount > 0,
            'unread_count': totalUnreadCount,
            'avatar_url': topChat['avatar_url'],
            'is_typing': isTypingGroup,
            'pinned': isPinnedGroup,
            'chat_sessions': userChats
                .map((chatItem) => Map<String, dynamic>.from(chatItem))
                .toList(),
            'session_ids': sessionIds,
            'has_multiple': hasMultiple,
            'last_updated': topChat['last_updated'],
            'is_requester': isRequesterGroup,
            'is_provider': isProviderGroup,
          };
          
          aggregatedChats.add(aggregatedChat);
        });

        aggregatedChats.sort((a, b) {
          final bTime = _parseDateTime(b['last_updated']);
          final aTime = _parseDateTime(a['last_updated']);
          return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
        });

        // Separate chats into requester and provider lists
        final List<Map<String, dynamic>> requesterChatsList = aggregatedChats
            .where((chat) => chat['is_requester'] == true)
            .toList()
          ..sort((a, b) {
            // Sort pinned chats to the top
            final aPinned = a['pinned'] == true;
            final bPinned = b['pinned'] == true;
            if (aPinned != bPinned) {
              return aPinned ? -1 : 1; // Pinned chats come first
            }
            // Then sort by last_updated
            final bTime = _parseDateTime(b['last_updated']);
            final aTime = _parseDateTime(a['last_updated']);
            return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
          });
        final List<Map<String, dynamic>> providerChatsList = aggregatedChats
            .where((chat) => chat['is_provider'] == true)
            .toList()
          ..sort((a, b) {
            // Sort pinned chats to the top
            final aPinned = a['pinned'] == true;
            final bPinned = b['pinned'] == true;
            if (aPinned != bPinned) {
              return aPinned ? -1 : 1; // Pinned chats come first
            }
            // Then sort by last_updated
            final bTime = _parseDateTime(b['last_updated']);
            final aTime = _parseDateTime(a['last_updated']);
            return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
          });

        setState(() {
          chats = aggregatedChats;
          requesterChats = requesterChatsList;
          providerChats = providerChatsList;
          filteredChats = _getCategorizedChats();
          _chatMessageCounts = newMessageCounts;
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

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
  
int _parseUnreadCountValue(dynamic unreadValue) {
  if (unreadValue is int) return unreadValue;
  if (unreadValue is String) return int.tryParse(unreadValue) ?? 0;
  if (unreadValue != null) {
    return int.tryParse(unreadValue.toString()) ?? 0;
  }
  return 0;
}

bool _chatHasUnread(Map<String, dynamic> chat) {
  if (chat['unread'] == true) return true;
  if (_parseUnreadCountValue(chat['unread_count']) > 0) return true;

  final List<Map<String, dynamic>> sessions =
      (chat['chat_sessions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

  for (final session in sessions) {
    if (session['unread'] == true) return true;
    if (_parseUnreadCountValue(session['unread_count']) > 0) return true;
  }
  return false;
}

// Calculate total unread count from all chats (counts chat/service groups)
int _getTotalUnreadCount() {
  return chats.where(_chatHasUnread).length;
}

// Calculate unread count for Services tab (provider chats)
int _getServicesTabUnreadCount() {
  return providerChats.where(_chatHasUnread).length;
}

// Calculate unread count for Chats tab (requester chats)
int _getChatsTabUnreadCount() {
  return requesterChats.where(_chatHasUnread).length;
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

  void _togglePinGroup(Map<String, dynamic> group) {
    final bool shouldPin = !(group['pinned'] == true);
    final List<Map<String, dynamic>> chatSessions = (group['chat_sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    setState(() {
      // Update pinned state for all individual chat sessions in the group
      for (final session in chatSessions) {
        final chatId = session['id'];
        if (chatId is int) {
          if (shouldPin) {
            pinnedChats.add(chatId);
          } else {
            pinnedChats.remove(chatId);
          }
        } else if (chatId is String) {
          final chatIdInt = int.tryParse(chatId);
          if (chatIdInt != null) {
            if (shouldPin) {
              pinnedChats.add(chatIdInt);
            } else {
              pinnedChats.remove(chatIdInt);
            }
          }
        }
      }

      // Update the group's pinned status in chats list
      chats = chats.map((chat) {
        if (chat['id'] == group['id']) {
          final updatedChat = Map<String, dynamic>.from(chat);
          updatedChat['pinned'] = shouldPin;
          return updatedChat;
        }
        return chat;
      }).toList();

      // Update requesterChats and providerChats to reflect the pinned state
      requesterChats = requesterChats.map((chat) {
        if (chat['id'] == group['id']) {
          final updatedChat = Map<String, dynamic>.from(chat);
          updatedChat['pinned'] = shouldPin;
          return updatedChat;
        }
        return chat;
      }).toList();

      providerChats = providerChats.map((chat) {
        if (chat['id'] == group['id']) {
          final updatedChat = Map<String, dynamic>.from(chat);
          updatedChat['pinned'] = shouldPin;
          return updatedChat;
        }
        return chat;
      }).toList();

      filteredChats = _getCategorizedChats();
    });
  }
  
  
  Future<Map<int, Map<String, dynamic>>> _fetchSessionDetails(List<int> sessionIds) async {
    Map<int, Map<String, dynamic>> fetched = {};
    if (sessionIds.isEmpty) {
      return fetched;
    }
    
    try {
      final response = await supabase
          .from('sessions')
          .select('id, status, skills (name)')
          .inFilter('id', sessionIds);
      
      for (final session in response) {
        final sessionId = session['id'];
        if (sessionId is int) {
          fetched[sessionId] = Map<String, dynamic>.from(session);
        }
      }
      
      if (fetched.isNotEmpty && mounted) {
        setState(() {
          _sessionDetailsCache.addAll(fetched);
        });
      }
    } catch (e) {
      log('Error fetching session details: $e');
    }
    
    return fetched;
  }
  
  void _openChatSession(
    Map<String, dynamic> chatSession, 
    String username, {
    bool? wasInGroup,
    Map<String, dynamic>? previousGroup,
  }) async {
    if (!mounted) return;
    
    int? chatId;
    final chatIdRaw = chatSession['id'];
    if (chatIdRaw is int) {
      chatId = chatIdRaw;
    } else if (chatIdRaw is String) {
      chatId = int.tryParse(chatIdRaw);
    }
    
    if (chatId == null || loggedInUserId == null) {
      log('Error: Unable to open chat session due to missing identifiers');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open this conversation',
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
    
    // Store current tab index before opening chat
    _previousTabIndex = _tabController.index;
    // Store if we were in group detail view (use passed parameter or current state)
    _wasInGroupView = wasInGroup ?? _showChatGroupDetail;
    _previousChatGroup = previousGroup ?? _currentChatGroup;
    
    // Update last known status when user opens the chat (marks status as seen)
    final sessionIdRaw = chatSession['session_id'];
    if (sessionIdRaw != null) {
      int? sessionId;
      if (sessionIdRaw is int) {
        sessionId = sessionIdRaw;
      } else if (sessionIdRaw is String) {
        sessionId = int.tryParse(sessionIdRaw);
      }
      
      if (sessionId != null) {
        try {
          // Fetch current session status
          final sessionResponse = await supabase
              .from('sessions')
              .select('status')
              .eq('id', sessionId)
              .maybeSingle();
          
          if (sessionResponse != null && sessionResponse['status'] != null) {
            final currentStatus = sessionResponse['status'].toString();
            // Update last known status so it won't count as unread anymore
            // This marks the status (including "Requested") as seen when user opens the chat
            _lastKnownSessionStatus[sessionId] = currentStatus;
            log('Marked session $sessionId status "$currentStatus" as seen when opening chat');
          }
        } catch (e) {
          log('Error fetching session status when opening chat: $e');
        }
      }
    }
    
    // Check if widget is still mounted before using context after async operation
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatId: chatId!,
          loggedInUserId: loggedInUserId!,
          otherUsername: username,
          initialTabIndex: _tabController.index, // Pass current tab index
        ),
      ),
    ).then((_) async {
      if (!mounted) return;
      
      // Restore the previous tab index immediately
      final savedTabIndex = _previousTabIndex;
      if (savedTabIndex != null) {
        // Set the tab index directly without animation for immediate effect
        if (_tabController.index != savedTabIndex) {
          _tabController.index = savedTabIndex;
        }
      }
      
      // Refresh chats when returning from chat page
      // Mark messages as read for this chat before refreshing
      try {
        await supabase
            .from('messages')
            .update({'read': true})
            .eq('chat_id', chatId!)
            .neq('sender_id', loggedInUserId.toString());
        log('Marked messages as read for chat $chatId when returning');
      } catch (e) {
        log('Error marking messages as read when returning: $e');
      }
      
      // Add a delay to ensure database updates are complete
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        // Ensure tab is still on the correct index after refresh
        if (savedTabIndex != null && _tabController.index != savedTabIndex) {
          _tabController.index = savedTabIndex;
        }
        
        // Clear cached message counts to force recalculation
        _chatMessageCounts.clear();
        // Reload chats to get fresh data with updated read status
        // The _lastKnownSessionStatus is already updated in _openChatSession,
        // so when _loadChats runs, it will see the status as "seen" and won't count it as unread
        await _loadChats();
        // Also refresh services to update any status changes
        _loadServicesReceived();
        _loadActiveServices();
        
        // If we were in the group detail view before opening the chat, restore it with updated data
        if (_wasInGroupView && _previousChatGroup != null) {
          // Find the updated group in the chats list
          try {
            final updatedGroup = chats.firstWhere(
              (chat) => chat['id'] == _previousChatGroup!['id'],
              orElse: () => _previousChatGroup!,
            );
            
            // Update the chat_sessions in the group with fresh unread counts from the reloaded data
            // The updatedGroup already has fresh data from _loadChats(), but we need to ensure
            // the specific chat we opened has its unread count set to 0
            if (updatedGroup['chat_sessions'] != null) {
              final List<Map<String, dynamic>> updatedSessions = [];
              for (final session in (updatedGroup['chat_sessions'] as List)) {
                final sessionMap = Map<String, dynamic>.from(session);
                // If this is the chat we just opened, set unread_count to 0 since we read it
                final sessionChatIdRaw = sessionMap['id'];
                int? sessionChatIdInt;
                if (sessionChatIdRaw is int) {
                  sessionChatIdInt = sessionChatIdRaw;
                } else if (sessionChatIdRaw is String) {
                  sessionChatIdInt = int.tryParse(sessionChatIdRaw);
                }
                
                // Compare chat IDs to find the one we just opened
                if (sessionChatIdInt != null && chatId != null && sessionChatIdInt == chatId) {
                  log('Updating unread count for chat $chatId in group - setting to 0');
                  sessionMap['unread_count'] = 0;
                  sessionMap['unread'] = false;
                }
                updatedSessions.add(sessionMap);
              }
              updatedGroup['chat_sessions'] = updatedSessions;
              // Recalculate total unread count for the group
              final int totalUnread = updatedSessions.fold<int>(0, (sum, s) {
                final unreadValue = s['unread_count'];
                if (unreadValue is int) return sum + unreadValue;
                if (unreadValue is String) return sum + (int.tryParse(unreadValue) ?? 0);
                return sum;
              });
              updatedGroup['unread_count'] = totalUnread;
              updatedGroup['unread'] = totalUnread > 0;
              log('Updated group unread count: $totalUnread');
            }
            
            setState(() {
              _currentChatGroup = updatedGroup;
              _showChatGroupDetail = true;
            });
          } catch (e) {
            log('Error finding updated group: $e');
            // If group not found, just restore the previous state
            setState(() {
              _currentChatGroup = _previousChatGroup;
              _showChatGroupDetail = true;
            });
          }
        }
        
        // Final check to ensure tab is correct after all operations
        if (mounted && savedTabIndex != null && _tabController.index != savedTabIndex) {
          _tabController.index = savedTabIndex;
        }
      }
    });
  }
  
  void _navigateToChatGroupPage(Map<String, dynamic> group) async {
    final List<Map<String, dynamic>> sessions = (group['chat_sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    if (sessions.isEmpty) return;
    if (sessions.length == 1) {
      _openChatSession(sessions.first, (group['username'] ?? 'Unknown User').toString());
      return;
    }
    
    final List<int> missingSessionIds = sessions
        .map((session) {
          final raw = session['session_id'];
          if (raw is int) return raw;
          if (raw is String) return int.tryParse(raw);
          return null;
        })
        .whereType<int>()
        .where((id) => !_sessionDetailsCache.containsKey(id))
        .toList();
    
    await _fetchSessionDetails(missingSessionIds);
    if (!mounted) return;
    
    // Update last known status for all sessions in the group (marks statuses as seen)
    for (final sessionId in missingSessionIds) {
      try {
        final sessionResponse = await supabase
            .from('sessions')
            .select('status')
            .eq('id', sessionId)
            .maybeSingle();
        
        if (sessionResponse != null && sessionResponse['status'] != null) {
          final currentStatus = sessionResponse['status'].toString();
          _lastKnownSessionStatus[sessionId] = currentStatus;
        }
      } catch (e) {
        log('Error fetching session status for group view: $e');
      }
    }
    
    // Also update status for sessions already in cache
    for (final session in sessions) {
      final raw = session['session_id'];
      int? sessionId;
      if (raw is int) {
        sessionId = raw;
      } else if (raw is String) {
        sessionId = int.tryParse(raw);
      }
      
      if (sessionId != null && _sessionDetailsCache.containsKey(sessionId)) {
        final cachedSession = _sessionDetailsCache[sessionId];
        if (cachedSession != null && cachedSession['status'] != null) {
          _lastKnownSessionStatus[sessionId] = cachedSession['status'].toString();
        }
      }
    }
    
    setState(() {
      _currentChatGroup = group;
      _showChatGroupDetail = true;
    });
  }
  
  void _goBackToChatList() {
    setState(() {
      _showChatGroupDetail = false;
      _currentChatGroup = null;
    });
  }
  
  Widget _buildChatGroupDetailView(Map<String, dynamic> group) {
    final List<Map<String, dynamic>> sessions = (group['chat_sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final String username = (group['username'] ?? 'Unknown User').toString();
    final String? avatarUrl = group['avatar_url'];
    final bool isUserOnline = _isUserOnline(group['user_id']);
    final int totalUnread = sessions.fold<int>(0, (sum, session) {
      final unreadValue = session['unread_count'];
      int unread = 0;
      if (unreadValue is int) {
        unread = unreadValue;
      } else if (unreadValue is String) {
        unread = int.tryParse(unreadValue) ?? 0;
      } else {
        unread = int.tryParse((unreadValue ?? '0').toString()) ?? 0;
      }
      return sum + unread;
    });
    
    return Column(
      children: [
        // Chat sessions list with gradient background
        Expanded(
          child: Container(
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
            child: Column(
              children: [
                // User info card with back button integrated
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _goBackToChatList,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.grey[700],
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // User Avatar
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF2196F3).withValues(alpha: 0.15),
                                  const Color(0xFF1976D2).withValues(alpha: 0.08),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildAvatarFallbackForCard(username),
                                    ),
                                  )
                                : _buildAvatarFallbackForCard(username),
                          ),
                          if (isUserOnline)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: _buildOnlineIndicatorDot(),
                            ),
                        ],
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1D29),
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isUserOnline) ...[
                                  const SizedBox(width: 8),
                                  _buildOnlineIndicatorDot(
                                    size: 10,
                                    borderWidth: 0,
                                    borderColor: Colors.transparent,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sessions.length} ${sessions.length == 1 ? 'conversation' : 'conversations'}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (totalUnread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2196F3),
                                Color(0xFF1976D2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mark_chat_unread_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                totalUnread > 99 ? '99+' : totalUnread.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Section header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Active Services with $username',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                // Chat sessions list
                Expanded(
                  child: sessions.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF2196F3).withValues(alpha: 0.1),
                                        const Color(0xFF1976D2).withValues(alpha: 0.05),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No conversations yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1D29),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start a conversation to see it here',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                    final session = sessions[index];
                    final sessionIdRaw = session['session_id'];
                    int? sessionId;
                    if (sessionIdRaw is int) {
                      sessionId = sessionIdRaw;
                    } else if (sessionIdRaw is String) {
                      sessionId = int.tryParse(sessionIdRaw);
                    }

                    final sessionDetails = sessionId != null ? _sessionDetailsCache[sessionId] : null;
                    final String skillName = sessionDetails?['skills']?['name']?.toString() ?? 'General chat';
                    final String status = sessionDetails?['status']?.toString() ?? 'Unknown';
                    final int unreadCount = session['unread_count'] is int
                        ? session['unread_count']
                        : int.tryParse((session['unread_count'] ?? '0').toString()) ?? 0;
                    final String lastMessagePreview = (session['last_message'] ?? 'No messages yet').toString();
                    final String timestamp = (session['timestamp'] ?? '').toString();
                    final bool hasUnread = unreadCount > 0;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: hasUnread
                                ? [
                                    const Color(0xFFEDF6FF),
                                    const Color(0xFFE1EFFF),
                                    Colors.white,
                                  ]
                                : [
                                    Colors.white,
                                    const Color(0xFFF8F9FF),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: hasUnread
                                  ? const Color(0xFF2196F3).withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: hasUnread ? 0 : -2,
                            ),
                            if (hasUnread)
                              BoxShadow(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                                spreadRadius: 0,
                              ),
                          ],
                          border: hasUnread
                              ? Border.all(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                                  width: 2,
                                )
                              : Border.all(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Store group state before going back (so we can restore it after returning from chat)
                              final wasInGroup = _showChatGroupDetail;
                              final currentGroup = _currentChatGroup;
                              _goBackToChatList();
                              // Pass group state to _openChatSession so it can restore it
                              _openChatSession(session, username, wasInGroup: wasInGroup, previousGroup: currentGroup);
                            },
                            onLongPress: () async {
                              await _confirmAndDeleteChat(session, username);
                            },
                            borderRadius: BorderRadius.circular(24),
                            splashColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
                            highlightColor: const Color(0xFF2196F3).withValues(alpha: 0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF2196F3).withValues(alpha: 0.15),
                                              const Color(0xFF1976D2).withValues(alpha: 0.08),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            skillName.isNotEmpty
                                                ? skillName[0].toUpperCase()
                                                : username[0].toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF2196F3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: unreadCount > 99 ? 7.0 : 8.0,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF2196F3),
                                                  Color(0xFF1976D2),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                skillName,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF1A1D29),
                                                  letterSpacing: -0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF2196F3).withValues(alpha: 0.12),
                                                    const Color(0xFF1976D2).withValues(alpha: 0.08),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                status,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF2196F3),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (timestamp.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: hasUnread 
                                                      ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                                                      : Colors.grey.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  timestamp,
                                                  style: GoogleFonts.poppins(
                                                    color: hasUnread ? const Color(0xFF2196F3) : Colors.grey[600],
                                                    fontSize: 12,
                                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          lastMessagePreview,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w400,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAvatarFallbackForCard(String username) {
    return Center(
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2196F3),
        ),
      ),
    );
  }
  
  Future<void> _showDeleteOptions(Map<String, dynamic> group) async {
    final List<Map<String, dynamic>> sessions = (group['chat_sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    if (sessions.isEmpty) return;
    final String username = (group['username'] ?? 'Unknown User').toString();
    
    if (sessions.length == 1) {
      await _confirmAndDeleteChat(sessions.first, username);
      return;
    }
    
    final List<int> missingSessionIds = sessions
        .map((session) {
          final raw = session['session_id'];
          if (raw is int) return raw;
          if (raw is String) return int.tryParse(raw);
          return null;
        })
        .whereType<int>()
        .where((id) => !_sessionDetailsCache.containsKey(id))
        .toList();
    
    await _fetchSessionDetails(missingSessionIds);
    if (!mounted) return;
    
    double sheetHeight = (sessions.length * 92).toDouble();
    if (sheetHeight < 200.0) sheetHeight = 200.0;
    if (sheetHeight > 400.0) sheetHeight = 400.0;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
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
                  'Delete a conversation',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select which service chat with $username you want to remove.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: sheetHeight,
                  child: ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final sessionIdRaw = session['session_id'];
                      int? sessionId;
                      if (sessionIdRaw is int) {
                        sessionId = sessionIdRaw;
                      } else if (sessionIdRaw is String) {
                        sessionId = int.tryParse(sessionIdRaw);
                      }
                      
                      final sessionDetails = sessionId != null ? _sessionDetailsCache[sessionId] : null;
                      final String skillName = sessionDetails?['skills']?['name']?.toString() ?? 'General chat';
                      final String lastMessagePreview = (session['last_message'] ?? 'No messages yet').toString();
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.1),
                          ),
                        ),
                        child: ListTile(
                          onTap: () async {
                            Navigator.pop(context);
                            await _confirmAndDeleteChat(session, username);
                          },
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red[600],
                            ),
                          ),
                          title: Text(
                            skillName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1D29),
                            ),
                          ),
                          subtitle: Text(
                            lastMessagePreview,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.red[600],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _confirmAndDeleteChat(Map<String, dynamic> session, String username) async {
    int? chatId;
    final chatIdRaw = session['id'];
    if (chatIdRaw is int) {
      chatId = chatIdRaw;
    } else if (chatIdRaw is String) {
      chatId = int.tryParse(chatIdRaw);
    }
    
    if (chatId == null) {
      log('Error: Unable to determine chat ID for deletion');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to delete this conversation',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }
    
    int? sessionId;
    final sessionIdRaw = session['session_id'];
    if (sessionIdRaw is int) {
      sessionId = sessionIdRaw;
    } else if (sessionIdRaw is String) {
      sessionId = int.tryParse(sessionIdRaw);
    }
    
    final String skillName = sessionId != null
        ? (_sessionDetailsCache[sessionId]?['skills']?['name']?.toString() ?? 'this service')
        : 'this service';
    
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Conversation?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1D29),
            ),
          ),
          content: Text(
            'Are you sure you want to delete your $skillName chat with $username? This will only remove the chat from your side, and the other user will still have access to it.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[600],
                ),
              ),
            ),
          ],
        );
      },
    );
    
    if (shouldDelete == true) {
      await _deleteChat(chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(180),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2196F3),
                Color(0xFF1976D2),
                Color(0xFF0D47A1),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Messages',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorWeight: 2,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('My Bookings'),
                              if (_getChatsTabUnreadCount() > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    _getChatsTabUnreadCount() > 99 ? '99+' : '${_getChatsTabUnreadCount()}',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2196F3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('My Offers'),
                              if (_getServicesTabUnreadCount() > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    _getServicesTabUnreadCount() > 99 ? '99+' : '${_getServicesTabUnreadCount()}',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2196F3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // Chats Tab
                _showChatGroupDetail && _currentChatGroup != null
                    ? _buildChatGroupDetailView(_currentChatGroup!)
                    : Column(
                        children: [
                          _buildCategorySelector(),
                          Expanded(child: _buildChatsList()),
                        ],
                      ),
                // Services Tab
                _showChatGroupDetail && _currentChatGroup != null
                    ? _buildChatGroupDetailView(_currentChatGroup!)
                    : Column(
                        children: [
                          _buildCategorySelector(),
                          Expanded(child: _buildActiveServicesList()),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 1,
        unreadCountOverride: _getTotalUnreadCount(),
      ),
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
                color: const Color(0xFF2196F3).withValues(alpha: 0.3),
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

  Widget _buildActiveServicesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: activeServicesFuture,
      builder: (context, snapshot) {
        final bool isLoadingServices = snapshot.connectionState == ConnectionState.waiting && activeServicesFuture == null;
        final bool hasServices = snapshot.hasData && snapshot.data!.isNotEmpty;
        final bool hasProviderChats = providerChats.isNotEmpty;
        
        if (isLoadingServices && !hasProviderChats) {
          return _buildLoadingState();
        }

        if (!hasServices && !hasProviderChats) {
          return _buildEmptyServiceState();
        }

        // Filter provider chats based on selected category
        List<Map<String, dynamic>> filteredProviderChats = providerChats;
        if (selectedCategory == 'Pinned') {
          filteredProviderChats = providerChats.where((chat) => chat['pinned'] == true).toList();
        } else if (selectedCategory == 'Unread') {
          filteredProviderChats = providerChats.where((chat) => chat['unread'] == true).toList();
        }
        
        // Filter active services based on selected category
        List<Map<String, dynamic>> filteredServices = hasServices ? snapshot.data! : [];
        if (selectedCategory == 'Pinned' && hasServices) {
          filteredServices = snapshot.data!.where((service) => service['pinned'] == true).toList();
        } else if (selectedCategory == 'Unread' && hasServices) {
          // For services, we might not have unread, so keep all for now
          // You can add unread logic for services if needed
        }
        
        // Check if we have any items after filtering
        final bool hasFilteredItems = filteredProviderChats.isNotEmpty || filteredServices.isNotEmpty;
        
        if (!hasFilteredItems) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.08),
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
                          const Color(0xFF2196F3).withValues(alpha: 0.1),
                          const Color(0xFF1976D2).withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.work_outline_rounded,
                      size: 64,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    selectedCategory == 'Pinned' 
                        ? 'No pinned services'
                        : selectedCategory == 'Unread'
                            ? 'No unread services'
                            : 'No services',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1D29),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedCategory == 'Pinned'
                        ? 'Pin services to see them here'
                        : selectedCategory == 'Unread'
                            ? 'All services are read'
                            : 'Services you are providing will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        // Combine filtered provider chats and active services
        final List<Widget> items = [];
        
        // Add filtered provider chats first
        for (final chat in filteredProviderChats) {
          items.add(_buildEnhancedChatTile(chat));
        }
        
        // Add filtered active services
        for (final serviceGroup in filteredServices) {
          items.add(_buildServiceProvidedTile(serviceGroup));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadChats();
            await _loadActiveServices();
          },
          color: const Color(0xFF2196F3),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, index) => items[index],
          ),
        );
      },
    );
  }

  Widget _buildChatsList() {
    if (isLoading && chats.isEmpty) {
      return _buildLoadingState();
    }

    if (filteredChats.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.08),
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
                      const Color(0xFF2196F3).withValues(alpha: 0.1),
                      const Color(0xFF1976D2).withValues(alpha: 0.05),
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
                'No chats yet',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1D29),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a conversation to see your chats here',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadChats();
      },
      color: const Color(0xFF2196F3),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: filteredChats.length,
        itemBuilder: (context, index) => _buildEnhancedChatTile(filteredChats[index]),
      ),
    );
  }

  Widget _buildServiceProvidedTile(Map<String, dynamic> serviceGroup) {
    final List<Map<String, dynamic>> services = (serviceGroup['services'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    final String requesterName = (serviceGroup['requester_name'] ?? 'Unknown Requester').toString();
    final String skillName = (serviceGroup['skill_name'] ?? 'Unknown Skill').toString();
    final String status = (serviceGroup['status'] ?? 'Pending').toString();
    final bool hasMultiple = serviceGroup['has_multiple'] == true && services.length > 1;
    final String timestamp = _formatMessageTime(_parseDateTime(serviceGroup['last_updated']));
    final bool isRequesterOnline = _isUserOnline(serviceGroup['requester_id']);
    
    // Get the first service for actions
    final firstService = services.isNotEmpty ? services.first : null;
    final serviceId = firstService?['session_id'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8F9FF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                // Navigate to service details or chat
                if (hasMultiple && services.isNotEmpty) {
                  // Show modal with multiple services
                } else if (services.isNotEmpty) {
                  // Open single service
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2196F3).withValues(alpha: 0.1),
                            const Color(0xFF1976D2).withValues(alpha: 0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          requesterName.isNotEmpty ? requesterName[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ),
                    ),
                    if (isRequesterOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: _buildOnlineIndicatorDot(),
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
                                    Expanded(
                                      child: Text(
                                        requesterName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: const Color(0xFF1A1D29),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasMultiple)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${services.length} services',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2196F3),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Only show timestamp if it's not a group (hasMultiple is false)
                              if (!hasMultiple)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    timestamp,
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  skillName,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF1A1D29),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
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
            if (firstService != null && serviceId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await DatabaseHelper.completeService(serviceId);
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
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Complete',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await DatabaseHelper.cancelService(serviceId);
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
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedChatTile(Map<String, dynamic> chat) {
    final List<Map<String, dynamic>> chatSessions = (chat['chat_sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    
    int? primaryChatId;
    int? primarySessionId;
    if (chatSessions.isNotEmpty) {
      final primaryChatIdRaw = chatSessions.first['id'];
      if (primaryChatIdRaw is int) {
        primaryChatId = primaryChatIdRaw;
      } else if (primaryChatIdRaw is String) {
        primaryChatId = int.tryParse(primaryChatIdRaw);
      }
      
      final primarySessionIdRaw = chatSessions.first['session_id'];
      if (primarySessionIdRaw is int) {
        primarySessionId = primarySessionIdRaw;
      } else if (primarySessionIdRaw is String) {
        primarySessionId = int.tryParse(primarySessionIdRaw);
      }
    }
    
    final animationController = primaryChatId != null ? _chatAnimationControllers[primaryChatId] : null;
    final animation = animationController?.drive(
      Tween<double>(begin: 0.0, end: 1.0),
    ) ?? const AlwaysStoppedAnimation(1.0);

    final String username = (chat['username'] ?? 'Unknown User').toString();
    final String lastMessage = (chat['last_message'] ?? 'No messages yet').toString();
    final String timestamp = (chat['timestamp'] ?? '').toString();
    final bool unread = chat['unread'] == true;
    final int unreadCount = chat['unread_count'] is int
        ? chat['unread_count']
        : int.tryParse((chat['unread_count'] ?? '0').toString()) ?? 0;
    final String? avatarUrl = chat['avatar_url'];
    final bool isOnline = _isUserOnline(chat['user_id']);
    final bool isTyping = chat['is_typing'] == true;
    final bool isPinned = chat['pinned'] == true;
    final bool hasMultiple = chat['has_multiple'] == true && chatSessions.length > 1;
    final String? primarySkillName = primarySessionId != null
        ? (_sessionDetailsCache[primarySessionId]?['skills']?['name'] as String?)
        : null;
    final String messagePreview;
    if (isTyping) {
      messagePreview = 'Typing...';
    } else if (!hasMultiple && primarySkillName != null && primarySkillName.isNotEmpty) {
      messagePreview = '$primarySkillName • $lastMessage';
    } else {
      messagePreview = lastMessage;
    }
    
    return FadeTransition(
      opacity: animation,
      child: Dismissible(
        key: Key('chat_group_${chat['id']}'),
        background: Container(
          padding: const EdgeInsets.only(left: 20),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF2196F3).withValues(alpha: 0.8),
                const Color(0xFF1976D2).withValues(alpha: 0.6),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        secondaryBackground: Container(
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.red.withValues(alpha: 0.8),
                Colors.red[700]!.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
          if (direction == DismissDirection.startToEnd) {
            _togglePinGroup(chat);
            return false;
          } else if (direction == DismissDirection.endToStart) {
            await _showDeleteOptions(chat);
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
                    ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: unread ? 0 : -2,
              ),
              if (unread) BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
            border: unread
                ? Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2), width: 1.5)
                : Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (loggedInUserId == null) {
                  log('Error: No logged in user ID available');
                  if (mounted) {
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
                  }
                  return;
                }
                
                if (chatSessions.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No conversations available for this user',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                  return;
                }
                
                if (hasMultiple) {
                  _navigateToChatGroupPage(chat);
                } else {
                  _openChatSession(chatSessions.first, username);
                }
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
                                const Color(0xFF2196F3).withValues(alpha: 0.1),
                                const Color(0xFF1976D2).withValues(alpha: 0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: unread ? [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.2),
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
                                          : const Color(0xFF2196F3).withValues(alpha: 0.7),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: _buildOnlineIndicatorDot(),
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
                                    Expanded(
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
                                    if (hasMultiple)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${chatSessions.length} chats',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2196F3),
                                          ),
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
                                            color: const Color(0xFF2196F3).withValues(alpha: 0.4),
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
                                  // Only show timestamp if it's not a group (hasMultiple is false)
                                  if (!hasMultiple)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: unread 
                                            ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.1),
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
                            messagePreview,
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
                _togglePinGroup(chat);
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Chat',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showDeleteOptions(chat);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChat(int chatId) async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Store the chat ID locally as deleted (soft delete)
      // This way we don't need database columns that may not exist
      deletedChatIds.add(chatId);
      await _saveDeletedChatIds();

      _removeChatFromState(chatId);

      pinnedChats.remove(chatId);

      await _loadChats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chat deleted successfully',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2196F3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting chat: $e',
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
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
                      ? Colors.red.withValues(alpha: 0.1)
                      : const Color(0xFF2196F3).withValues(alpha: 0.1),
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
              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
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

  Widget _buildEmptyServiceState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2196F3).withValues(alpha: 0.1),
                    const Color(0xFF1976D2).withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 64,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Services Provided',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Services you are providing will appear here',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to explore services
              },
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: Text(
                'Explore Services',
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
        ),
      ),
    );
  }
}