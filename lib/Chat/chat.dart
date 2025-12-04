import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Chat/chat_session_util.dart';
import 'package:sklr/Profile/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database.dart';
import '../database/user_id_storage.dart';
import 'chats_home.dart';
import 'dart:developer';

final supabase = Supabase.instance.client;

class ChatPage extends StatefulWidget {
  final int chatId;
  final int loggedInUserId; 
  final String otherUsername;
  final int? initialTabIndex; // Tab index to restore when returning

  const ChatPage({
    super.key,
    required this.chatId,
    required this.loggedInUserId,
    required this.otherUsername,
    this.initialTabIndex,
  });

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> messages;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;
  Map<String, dynamic>? session;
  
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadMessages();
    _setupRealTimeListener();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _slideController.forward();
  }

  RealtimeChannel? _messagesChannel;

  void _setupRealTimeListener() {
    _messagesChannel = supabase.channel('messages_${widget.chatId}');
    _messagesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            _loadMessagesQuietly();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    // Only remove the specific messages channel, not all channels
    // This preserves the global presence channel used by PresenceService
    if (_messagesChannel != null) {
      _messagesChannel!.unsubscribe();
      _messagesChannel = null;
    }
    _animationController.dispose();
    _slideController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _initializeMessages() async {
    try {
      log('Initializing messages for chat ${widget.chatId}');
      final messagesResponse = await supabase
          .from('messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('timestamp', ascending: false);
          
      log('Fetched ${messagesResponse.length} messages for chat ${widget.chatId}');
      return List<Map<String, dynamic>>.from(messagesResponse);
    } catch (e) {
      log('Error initializing messages for chat ${widget.chatId}: $e');
      return [];
    }
  }

  Future<void> _loadMessagesQuietly() async {
    if (!mounted) return;
    
    try {
      final messagesList = await _initializeMessages();
      await _markMessagesAsRead();
      
      if (mounted) {
        setState(() {
          messages = Future.value(messagesList);
        });
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scrollController.hasClients && _scrollController.offset < 100) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    try {
      final messagesList = await _initializeMessages();
      await _markMessagesAsRead();
      
      if (mounted) {
        setState(() {
          messages = Future.value(messagesList);
          isLoading = false;
        });
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Error loading messages: $e');
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() => isLoading = true);
    _messageController.clear();
    
    try {
      Map<String, dynamic>? chatData;
      try {
        chatData = await supabase
            .from('chats')
            .select('session_id, user1_id, user2_id')
            .eq('id', widget.chatId)
            .single();
      } catch (e) {
        log('Error getting chat data: $e');
        chatData = await supabase
            .from('chats')
            .select('session_id, user1_id, user2_id')
            .eq('id', widget.chatId)
            .maybeSingle();
      }
          
      if (chatData == null || !chatData.containsKey('session_id') || chatData['session_id'] == null) {
        log('No session found for chat ${widget.chatId}, attempting to create one');
        
        int user1Id = 0;
        int user2Id = 0;
        
        try {
          if (chatData != null && chatData.containsKey('user1_id') && chatData.containsKey('user2_id')) {
            user1Id = int.parse(chatData['user1_id'].toString());
            user2Id = int.parse(chatData['user2_id'].toString());
          } else {
            final chatUsers = await supabase
                .from('chats')
                .select('user1_id, user2_id')
                .eq('id', widget.chatId)
                .maybeSingle();
                
            if (chatUsers != null) {
              user1Id = int.parse(chatUsers['user1_id'].toString());
              user2Id = int.parse(chatUsers['user2_id'].toString());
            }
          }
          
          if (user1Id > 0 && user2Id > 0) {
            int providerId = widget.loggedInUserId;
            int requesterId = widget.loggedInUserId == user1Id ? user2Id : user1Id;
            
            final existingSkills = await supabase
                .from('skills')
                .select('id')
                .eq('user_id', providerId)
                .limit(1)
                .maybeSingle();
                
            int skillId = 1;
            if (existingSkills != null && existingSkills.containsKey('id')) {
              skillId = existingSkills['id'];
            }
            
            final dummySession = {
              'requester_id': requesterId,
              'provider_id': providerId,
              'skill_id': skillId,
              'status': 'Basic',
              'created_at': DateTime.now().toIso8601String(),
            };
            
            Map<String, dynamic>? sessionResult;
            try {
              final result = await supabase
                  .from('sessions')
                  .insert(dummySession)
                  .select();
                  
              if (result.isNotEmpty) {
                sessionResult = result[0];
              }
            } catch (e) {
              log('Error creating session: $e');
            }
                
            if (sessionResult != null) {
              final sessionId = sessionResult['id'];
              log('Created fallback session ID: $sessionId');
              
              await supabase
                  .from('chats')
                  .update({'session_id': sessionId})
                  .eq('id', widget.chatId);
                  
              final newMessage = {
                'chat_id': widget.chatId,
                'sender_id': widget.loggedInUserId.toString(),
                'message': messageText,
                'timestamp': DateTime.now().toIso8601String(),
                'read': false,
              };
              
              await supabase
                  .from('messages')
                  .insert(newMessage);
                  
              await _loadMessages();
              setState(() => isLoading = false);
              return;
            }
          }
        } catch (sessionError) {
          log('Error creating fallback session: $sessionError');
        }
        
        _showSnackBar('Unable to send message: No session found for this chat');
        setState(() => isLoading = false);
        return;
      }
      
      Map<String, dynamic>? sessionData;
      try {
        sessionData = await supabase
            .from('sessions')
            .select()
            .eq('id', chatData['session_id'])
            .single();
      } catch (e) {
        log('Error getting session data: $e');
        sessionData = await supabase
            .from('sessions')
            .select()
            .eq('id', chatData['session_id'])
            .maybeSingle();
      }
      
      if (sessionData == null) {
        log('Unable to send message: Session not found for ID ${chatData['session_id']}');
        _showSnackBar('Unable to send message: Session not found');
        setState(() => isLoading = false);
        return;
      }
      
      final recipientId = sessionData['requester_id'].toString() == widget.loggedInUserId.toString()
          ? sessionData['provider_id']
          : sessionData['requester_id'];
      
      final newMessage = {
        'chat_id': widget.chatId,
        'sender_id': widget.loggedInUserId.toString(),
        'message': messageText,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      final result = await supabase
          .from('messages')
          .insert(newMessage)
          .select();
          
      log('Message sent: ${result.isNotEmpty ? result[0]['id'] : 'unknown'}');
      
      await supabase
          .from('chats')
          .update({
            'last_message': messageText,
            'last_updated': DateTime.now().toIso8601String()
          })
          .eq('id', widget.chatId);
      
      try {
        Map<String, dynamic>? userData;
        try {
          userData = await supabase
              .from('users')
              .select('username, avatar_url')
              .eq('id', widget.loggedInUserId)
              .single();
        } catch (e) {
          userData = await supabase
              .from('users')
              .select('username, avatar_url')
              .eq('id', widget.loggedInUserId)
              .maybeSingle();
        }
            
        final senderName = userData != null && userData.containsKey('username') 
            ? (userData['username'] ?? 'Unknown User') 
            : 'Unknown User';
        final senderImage = userData != null ? userData['avatar_url'] : null;
        
        final notificationData = {
          'user_id': recipientId,
          'message': '$senderName: $messageText',
          'sender_id': widget.loggedInUserId.toString(),
          'sender_image': senderImage,
          'read': false,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        try {
          await supabase
              .from('notifications')
              .insert(notificationData);
              
          log('Notification created for recipient $recipientId');
        } catch (notificationInsertError) {
          log('Error inserting notification directly: $notificationInsertError');
          
          final notificationSuccess = await DatabaseHelper.createNotification(
            recipientId: int.parse(recipientId.toString()),
            message: '$senderName: $messageText',
            senderId: widget.loggedInUserId, 
            senderImage: senderImage,
            chatId: widget.chatId
          );
          
          if (!notificationSuccess) {
            log('Warning: Failed to create notification with DatabaseHelper');
          }
        }
      } catch (notificationError) {
        log('Warning: Error sending notification: $notificationError');
      }
      
      await _loadMessages();
      setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        log('Error sending message: $e');
        _showSnackBar('Failed to send message: $e');
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await supabase
          .from('messages')
          .update({'read': true})
          .eq('chat_id', widget.chatId)
          .neq('sender_id', widget.loggedInUserId.toString());
          
      log('Marked messages as read for chat ${widget.chatId}');
    } catch (e) {
      log('Error marking messages as read: $e');
      
      try {
        await supabase
            .from('messages')
            .update({'read': true})
            .eq('chat_id', widget.chatId)
            .neq('sender_id', widget.loggedInUserId.toString());
      } catch (retryError) {
        log('Failed retry to mark messages as read: $retryError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Ensure messages are marked as read before navigating back
          await _markMessagesAsRead();
          // Small delay to ensure database update completes
          await Future.delayed(const Duration(milliseconds: 200));
          // Navigate back and restore the correct tab
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            this.context,
            MaterialPageRoute(
              builder: (context) => ChatsHomePage(initialTabIndex: widget.initialTabIndex),
            ),
            (route) => false,
          );
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.grey[50],
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
            child: Column(
              children: [
                _buildModernAppBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: RefreshIndicator(
                        onRefresh: _loadMessages,
                        color: const Color(0xFF2196F3),
                        child: _buildMessageList(),
                      ),
                    ),
                  ),
                ),
                _buildSessionStatus(),
                _buildModernMessageInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () async {
                    // Ensure messages are marked as read before navigating back
                    await _markMessagesAsRead();
                    // Small delay to ensure database update completes
                    await Future.delayed(const Duration(milliseconds: 200));
                    // Navigate back and restore the correct tab
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatsHomePage(initialTabIndex: widget.initialTabIndex),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _loadSessionAndSkill(),
                  builder: (context, snapshot) {
                    final username = (snapshot.hasData && 
                                    snapshot.data!.containsKey('otherUsername') && 
                                    snapshot.data!['otherUsername'] != null && 
                                    snapshot.data!['otherUsername'] != 'Unknown User') 
                        ? snapshot.data!['otherUsername'] 
                        : widget.otherUsername;
                        
                    return GestureDetector(
                      onTap: () {
                        if (snapshot.hasData && snapshot.data != null && 
                            snapshot.data!.containsKey('session') && 
                            snapshot.data!['session'] != null) {
                          final sessionData = snapshot.data!['session'];
                          int otherUserId;
                          
                          if (sessionData.containsKey('provider_id') && 
                              sessionData.containsKey('requester_id') &&
                              sessionData['provider_id'] != 0 && 
                              sessionData['requester_id'] != 0) {
                            
                            if (sessionData['provider_id'].toString() == widget.loggedInUserId.toString()) {
                              otherUserId = sessionData['requester_id'];
                            } else {
                              otherUserId = sessionData['provider_id'];
                            }
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserPage(userId: otherUserId),
                              ),
                            );
                          } else {
                            _showSnackBar('Cannot access user profile: session data incomplete');
                          }
                        } else {
                          _showSnackBar('Cannot access user profile: session data not available');
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2196F3),
                                  Color(0xFF1976D2),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (snapshot.connectionState == ConnectionState.waiting)
                                  Text(
                                    'Loading...',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  )
                                else if (snapshot.hasError)
                                  Text(
                                    'Error loading skill info',
                                    style: GoogleFonts.poppins(
                                      color: Colors.red[100],
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  Text(
                                    snapshot.data?['skillName'] ?? 'Unknown Skill',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loadMessages,
                  tooltip: 'Refresh messages',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3)),
              strokeWidth: 3,
            ),
          )
        : FutureBuilder<List<Map<String, dynamic>>>(
            future: messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3)),
                    strokeWidth: 3,
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: GoogleFonts.poppins(
                            color: Colors.red[700],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull to refresh',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final messagesList = snapshot.data ?? [];
              if (messagesList.isEmpty) {
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
                            size: 48,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1A1D29),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messagesList.length,
                itemBuilder: (context, index) {
                  final message = messagesList[index];
                  final bool isSentByUser = message['sender_id'].toString() == widget.loggedInUserId.toString();
                  final bool isNextSameSender = index > 0 &&
                      messagesList[index - 1]['sender_id'].toString() == message['sender_id'].toString();
                  final bool isPrevSameSender = index < messagesList.length - 1 &&
                      messagesList[index + 1]['sender_id'].toString() == message['sender_id'].toString();

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: isPrevSameSender ? 4 : 12,
                      top: isNextSameSender ? 4 : 12,
                    ),
                    child: _buildModernMessageBubble(message, isSentByUser),
                  );
                },
              );
            },
          );
  }

  Widget _buildModernMessageBubble(Map<String, dynamic> message, bool isSentByUser) {
    if (message['sender_id'] == -1) {
      return _buildSystemMessage(message);
    }

    return Align(
      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isSentByUser ? 50 : 0,
          right: isSentByUser ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: isSentByUser
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2196F3),
                    Color(0xFF1976D2),
                  ],
                )
              : null,
          color: isSentByUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isSentByUser ? 24 : 8),
            bottomRight: Radius.circular(isSentByUser ? 8 : 24),
          ),
          boxShadow: [
            BoxShadow(
              color: isSentByUser 
                ? const Color(0xFF2196F3).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Text(
          message['message'],
          style: GoogleFonts.poppins(
            color: isSentByUser ? Colors.white : const Color(0xFF1A1D29),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2196F3).withValues(alpha: 0.1),
                const Color(0xFF1976D2).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2196F3).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            message['message'],
            style: GoogleFonts.poppins(
              color: const Color(0xFF2196F3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStatus() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3)),
                strokeWidth: 3,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          log('Error in _buildSessionStatus: ${snapshot.error}');
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.white,
            child: Text(
              "Error loading session data",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[400],
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          final status = snapshot.data!.containsKey('status') ? 
              snapshot.data!['status'] : 'Idle';
          
          return _buildStateButton(status, snapshot.data!);
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            "Basic chat mode",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStateButton(String status, Map<String, dynamic> session) {
    if (!session.containsKey('provider_id') || !session.containsKey('requester_id')) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Text(
          "Basic chat mode - session data incomplete",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      );
    }
    
    final bool isProvider = session['provider_id'].toString() == widget.loggedInUserId.toString();
    final bool isRequester = session['requester_id'].toString() == widget.loggedInUserId.toString();
    
    if (!isProvider && !isRequester) {
      return const SizedBox.shrink();
    }
    
    if (isProvider) {
      switch (status) {
        case 'Requested':
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Service Request Pending Your Approval",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleServiceAccept(session),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                              'Accept',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleServiceDecline(session),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                              'Decline',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        case 'Pending':
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleServiceComplete(session),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleServiceCancel(session),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        default:
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Text(
              "You are providing this service",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2196F3),
              ),
            ),
          );
      }
    }

    switch (status) {
      case 'Idle':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => _handleServiceRequest(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.handshake_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Request Service',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'Requested':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            "Service request sent. Waiting for provider to accept.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.orange[700],
            ),
          ),
        );

      case 'Pending':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleServiceComplete(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleServiceCancel(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case 'Completed':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            "This service has been completed",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        );

      case 'Cancelled':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            "This service was cancelled",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
        );
        
      case 'Declined':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Text(
            "This service request was declined by the provider",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildModernMessageInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[50]!,
                      Colors.grey[100]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF1A1D29),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2196F3),
                    Color(0xFF1976D2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _handleSendMessage,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Service handling methods
  Future<void> _handleServiceRequest(Map<String, dynamic> session) async {
    try {
      bool? result = await RequestService(session: session)
          .showRequestDialog(context);
          
      if (result == true) {
        try {
          final sessionId = session['id'];
          
          await supabase
              .from('sessions')
              .update({'status': 'Requested'})
              .eq('id', sessionId);
              
          await DatabaseHelper.sendMessage(
            widget.chatId,
            -1,
            'Service requested. Waiting for provider to accept.',
          );
          
          final requesterName = await _getUserName(session['requester_id']);
          final skillName = await _getSkillName(session['skill_id']);
          
          await DatabaseHelper.createNotification(
            recipientId: int.parse(session['provider_id'].toString()),
            message: '$requesterName has requested your service: $skillName',
            senderId: int.parse(session['requester_id'].toString()),
          );

          // Update the chat's last_updated timestamp
          await supabase
              .from('chats')
              .update({
                'last_message': 'Service requested',
                'last_updated': DateTime.now().toIso8601String()
              })
              .eq('id', widget.chatId);
          
          setState(() {
            _loadSession();
            _loadMessages();
          });
        } catch (e) {
          debugPrint('Error updating service status: $e');
          _showSnackBar('Error updating service: $e');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to request service: $e');
    }
  }
  
  Future<String> _getUserName(dynamic userId) async {
    try {
      final userData = await supabase
          .from('users')
          .select('username')
          .eq('id', userId)
          .single();
      return userData['username'] ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }
  
  Future<String> _getSkillName(dynamic skillId) async {
    try {
      final skillData = await supabase
          .from('skills')
          .select('name')
          .eq('id', skillId)
          .single();
      return skillData['name'] ?? 'Unknown Service';
    } catch (e) {
      return 'Unknown Service';
    }
  }

  Future<void> _handleServiceComplete(Map<String, dynamic> session) async {
    try {
      bool? result = await CompleteService(session: session)
          .showFinalizeDialog(context);
      if (result == true) {
        await DatabaseHelper.sendMessage(
          widget.chatId,
          -1,
          'The Service Completion has been confirmed by ${session['provider_id'].toString() == widget.loggedInUserId.toString() ? 'the provider' : 'the requester'}.',
        );

        // Update the chat's last_updated timestamp
        await supabase
            .from('chats')
            .update({
              'last_message': 'Service completed',
              'last_updated': DateTime.now().toIso8601String()
            })
            .eq('id', widget.chatId);

        setState(() {
          _loadSession();
          _loadMessages();
        });
      }
    } catch (e) {
      _showSnackBar('Failed to complete service: $e');
    }
  }

  Future<void> _handleServiceCancel(Map<String, dynamic> session) async {
    try {
      bool? result = await CancelService(session: session)
          .showFinalizeDialog(context);
      if (result == true) {
        await DatabaseHelper.sendMessage(
          widget.chatId,
          -1,
          'The Service was Cancelled by ${session['provider_id'].toString() == widget.loggedInUserId.toString() ? 'the provider' : 'the requester'}.',
        );

        // Update the chat's last_updated timestamp
        await supabase
            .from('chats')
            .update({
              'last_message': 'Service cancelled',
              'last_updated': DateTime.now().toIso8601String()
            })
            .eq('id', widget.chatId);

        setState(() {
          _loadSession();
          _loadMessages();
        });
      }
    } catch (e) {
      _showSnackBar('Failed to cancel service: $e');
    }
  }

  Future<void> _handleServiceAccept(Map<String, dynamic> session) async {
    try {
      final loggedInUserId = await UserIdStorage.getLoggedInUserId();
      if (loggedInUserId == null) return;
      
      final isProvider = session['provider_id'].toString() == loggedInUserId.toString();
      if (!isProvider) {
        _showSnackBar('Only the provider can accept service requests', backgroundColor: Colors.red);
        return;
      }
      
      RequestService requestService = RequestService(session: session);
      
      if (!mounted) return;
      final bool? result = await requestService.showAcceptDialog(context);
      
      if (result == true) {
        // Update the chat's last_updated timestamp
        await supabase
            .from('chats')
            .update({
              'last_message': 'Service request accepted',
              'last_updated': DateTime.now().toIso8601String()
            })
            .eq('id', widget.chatId);

        setState(() {
          messages = _initializeMessages();
        });
      }
    } catch (e) {
      debugPrint('Error accepting service: $e');
      _showSnackBar('Error accepting service: $e', backgroundColor: Colors.red);
    }
  }
  
  Future<void> _handleServiceDecline(Map<String, dynamic> session) async {
    try {
      // Update the chat's last_updated timestamp
      await supabase
          .from('chats')
          .update({
            'last_message': 'Service request declined',
            'last_updated': DateTime.now().toIso8601String()
          })
          .eq('id', widget.chatId);

      setState(() {
        messages = _initializeMessages();
      });
    } catch (e) {
      debugPrint('Error declining service: $e');
      _showSnackBar('Error declining service: $e', backgroundColor: Colors.red);
    }
  }

  // Helper methods
  Future<Map<String, dynamic>> _loadSession() async {
    try {
      log('Fetching session data for chat ${widget.chatId}');
      Map<String, dynamic>? chatData;
      try {
        chatData = await supabase
            .from('chats')
            .select('session_id, user1_id, user2_id')
            .eq('id', widget.chatId)
            .single();
      } catch (e) {
        chatData = await supabase
            .from('chats')
            .select('session_id, user1_id, user2_id')
            .eq('id', widget.chatId)
            .maybeSingle();
      }
          
      if (chatData == null || !chatData.containsKey('session_id') || chatData['session_id'] == null) {
        log('No session found for chat ID: ${widget.chatId}. Creating a new session.');
        await _verifySessionExists();
        
        chatData = await supabase
            .from('chats')
            .select('session_id, user1_id, user2_id')
            .eq('id', widget.chatId)
            .maybeSingle();
            
        if (chatData == null || !chatData.containsKey('session_id') || chatData['session_id'] == null) {
          log('Still could not get valid session for chat ${widget.chatId}');
          return {'status': 'Basic', 'provider_id': widget.loggedInUserId, 'requester_id': 0, 'skill_id': 1};
        }
      }
      
      Map<String, dynamic>? sessionData;
      try {
        sessionData = await supabase
            .from('sessions')
            .select()
            .eq('id', chatData['session_id'])
            .single();
      } catch (e) {
        sessionData = await supabase
            .from('sessions')
            .select()
            .eq('id', chatData['session_id'])
            .maybeSingle();
      }
      
      if (sessionData == null) {
        log('Session data not found for session ID: ${chatData['session_id']}');
        await _verifySessionExists();
        return {'status': 'Basic', 'provider_id': widget.loggedInUserId, 'requester_id': 0, 'skill_id': 1};
      }
      
      session = sessionData;
      return sessionData;
    } catch (err) {
      log('Error loading session: $err');
      return {'status': 'Basic', 'provider_id': widget.loggedInUserId, 'requester_id': 0, 'skill_id': 1};
    }
  }

  Future<Map<String, dynamic>> _loadSessionAndSkill() async {
    try {
      final chatData = await supabase
          .from('chats')
          .select('session_id, user1_id, user2_id')
          .eq('id', widget.chatId)
          .maybeSingle();
      
      if (chatData == null || !chatData.containsKey('session_id')) {
        log('No session found for chat ID: ${widget.chatId}');
        return {
          'skillName': 'Unknown Skill',
          'session': {'provider_id': 0, 'requester_id': 0},
          'otherUsername': widget.otherUsername
        };
      }
      
      final otherUserId = chatData['user1_id'].toString() == widget.loggedInUserId.toString()
          ? chatData['user2_id']
          : chatData['user1_id'];
          
      try {
        final sessionData = await supabase
            .from('sessions')
            .select('*, skills(*)')
            .eq('id', chatData['session_id'])
            .maybeSingle();
            
        final userData = await supabase
            .from('users')
            .select('username, avatar_url')
            .eq('id', otherUserId)
            .maybeSingle();
            
        if (sessionData == null || userData == null) {
          log('Session data or user data not found');
          return {
            'skillName': 'Unknown Skill',
            'session': {'provider_id': 0, 'requester_id': 0},
            'otherUsername': widget.otherUsername
          };
        }
        
        final skillName = sessionData['skills'] != null && sessionData['skills'].isNotEmpty ? 
            sessionData['skills']['name'] : 'Unknown Skill';
            
        return {
          'skillName': skillName,
          'session': sessionData,
          'otherUsername': userData['username'] ?? widget.otherUsername
        };
      } catch (e) {
        log('Error retrieving session or user data: $e');
        return {
          'skillName': 'Unknown Skill',
          'session': {'provider_id': 0, 'requester_id': 0},
          'otherUsername': widget.otherUsername
        };
      }
    } catch (err) {
      log('Error loading session data: $err');
      return {
        'skillName': 'Unknown Skill',
        'session': {'provider_id': 0, 'requester_id': 0},
        'otherUsername': widget.otherUsername
      };
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

Future<void> _verifySessionExists() async {
  log('Verifying session exists for chat ${widget.chatId}');
  try {
    final chatData = await supabase
        .from('chats')
        .select('session_id, user1_id, user2_id')
        .eq('id', widget.chatId)
        .single();
        
    if (!chatData.containsKey('session_id') || chatData['session_id'] == null) {
      log('No session found for chat ${widget.chatId}, creating one');
      
      if (chatData.containsKey('user1_id') && chatData.containsKey('user2_id')) {
        final user1Id = int.parse(chatData['user1_id'].toString());
        final user2Id = int.parse(chatData['user2_id'].toString());
        
        // Determine provider and requester
        int providerId = widget.loggedInUserId;
        int requesterId = widget.loggedInUserId == user1Id ? user2Id : user1Id;
        
        // Get a skill ID for the session
        final existingSkills = await supabase
            .from('skills')
            .select('id')
            .eq('user_id', providerId)
            .limit(1)
            .maybeSingle();
            
        int skillId = 1; // Default fallback
        if (existingSkills != null && existingSkills.containsKey('id')) {
          skillId = existingSkills['id'];
        }
        
        // Create new session
        final newSession = {
          'requester_id': requesterId,
          'provider_id': providerId,
          'skill_id': skillId,
          'status': 'Idle',
          'created_at': DateTime.now().toIso8601String(),
        };
        
        try {
          final sessionResult = await supabase
              .from('sessions')
              .insert(newSession)
              .select()
              .single();
              
          final sessionId = sessionResult['id'];
          log('Created new session with ID: $sessionId');
          
          // Update chat with session ID
          await supabase
              .from('chats')
              .update({'session_id': sessionId})
              .eq('id', widget.chatId);
              
          log('Updated chat ${widget.chatId} with session ID: $sessionId');
        } catch (sessionError) {
          log('Error creating session: $sessionError');
        }
      } else {
        log('Chat data incomplete, cannot create session');
      }
    }
  } catch (e) {
    log('Error in _verifySessionExists: $e');
  }
}
}