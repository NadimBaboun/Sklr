import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Chat/chatSessionUtil.dart';
import 'package:sklr/Profile/user.dart';
import '../database/database.dart';
import '../database/userIdStorage.dart';
import '../Util/navigationbar-bar.dart';
import 'chatsHome.dart';
import '../Home/home.dart';
import '../Skills/myOrders.dart';
import '../Profile/profile.dart';
import '../Support/supportMain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

class ChatPage extends StatefulWidget {
  final int chatId;
  final int loggedInUserId; 
  final String otherUsername;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.loggedInUserId,
    required this.otherUsername,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<List<Map<String, dynamic>>> messages;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;
  Map<String, dynamic>? session;

  @override
  void initState() {
    super.initState();
    messages = _initializeMessages();
    _markMessagesAsRead();
    // Fetch session data
    _fetchSessionData();
    // Set up periodic refresh every 10 seconds
    _startPeriodicRefresh();
  }

  Future<List<Map<String, dynamic>>> _initializeMessages() async {
    try {
      // Directly query messages from Supabase to ensure fresh data
      final messagesResponse = await supabase
          .from('messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('timestamp', ascending: false);
          
      log('Fetched ${messagesResponse.length} messages for chat ${widget.chatId}');
      return List<Map<String, dynamic>>.from(messagesResponse);
    } catch (e) {
      debugPrint('Error initializing messages: $e');
      return [];
    }
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _loadMessages();
        _startPeriodicRefresh();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      
      // Scroll to bottom after messages load
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e'))
        );
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() => isLoading = true);
    _messageController.clear();
    
    try {
      // Get the chat info with session_id
      final chatData = await supabase
          .from('chats')
          .select('session_id, user1_id, user2_id')
          .eq('id', widget.chatId)
          .single();
          
      if (chatData == null || !chatData.containsKey('session_id')) {
        throw Exception('No session found for this chat');
      }
      
      // Then get the session using that ID
      final sessionData = await supabase
          .from('sessions')
          .select()
          .eq('id', chatData['session_id'])
          .single();
      
      // Determine the recipient (the other user, not the sender)
      final recipientId = sessionData['requester_id'].toString() == widget.loggedInUserId.toString()
          ? sessionData['provider_id']
          : sessionData['requester_id'];
      
      // Important: Don't include an ID field to avoid duplicate key errors
      final newMessage = {
        'chat_id': widget.chatId,
        'sender_id': widget.loggedInUserId.toString(),
        'message': messageText,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      // Let Supabase auto-generate the ID by NOT specifying .single()
      // which was causing problems with the returned data
      final result = await supabase
          .from('messages')
          .insert(newMessage)
          .select();
          
      log('Message sent: ${result.isNotEmpty ? result[0]['id'] : 'unknown'}');
      
      // Update the chat's last_updated timestamp
      await supabase
          .from('chats')
          .update({
            'last_message': messageText,
            'last_updated': DateTime.now().toIso8601String()
          })
          .eq('id', widget.chatId);
      
      // Send notification to recipient
      final userData = await supabase
          .from('users')
          .select()
          .eq('id', widget.loggedInUserId)
          .single();
          
      final senderName = userData['username'] ?? 'Unknown User';
      final senderImage = userData['avatar_url'];
      
      // Create notification - Remove chat_id field since it's not in the schema
      final notificationData = {
        'user_id': recipientId,
        'message': '$senderName: $messageText',
        'sender_id': widget.loggedInUserId.toString(),
        'sender_image': senderImage,
        // 'chat_id' field removed since it doesn't exist in the schema
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Use DatabaseHelper to safely create notification
      final notificationSuccess = await DatabaseHelper.createNotification(
        recipientId: int.parse(recipientId.toString()),
        message: '$senderName: $messageText',
        senderId: widget.loggedInUserId, 
        senderImage: senderImage,
        chatId: widget.chatId
      );
      
      if (!notificationSuccess) {
        log('Warning: Failed to create notification, but message was sent');
      }
      
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        debugPrint('Error sending message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      // Mark all messages not sent by current user as read
      await supabase
          .from('messages')
          .update({'read': true})
          .eq('chat_id', widget.chatId)
          .neq('sender_id', widget.loggedInUserId.toString());
          
      log('Marked messages as read for chat ${widget.chatId}');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ChatsHomePage()),
          (route) => false,
        );
        return false;
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: _buildAppBar(),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadMessages,
                  color: const Color(0xFF6296FF),
                  child: _buildMessageList(),
                ),
              ),
              _buildSessionStatus(),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(85),
      child: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6296FF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            // Navigate to ChatsHomePage when back button is pressed
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const ChatsHomePage()),
              (route) => false,
            );
          },
        ),
        title: FutureBuilder<Map<String, dynamic>>(
          future: _loadSessionAndSkill(),
          builder: (context, snapshot) {
            // Get username from snapshot or fall back to widget.otherUsername
            final username = snapshot.hasData 
                ? snapshot.data!['otherUsername'] 
                : widget.otherUsername;
                
            return GestureDetector(
              onTap: () {
                // Only navigate if we have session data
                if (snapshot.hasData && snapshot.data != null) {
                  final sessionData = snapshot.data!['session'];
                  int otherUserId;
                  
                  // Determine which user ID to use based on who is logged in
                  if (sessionData['provider_id'] == widget.loggedInUserId) {
                    // If logged-in user is the provider, navigate to requester's profile
                    otherUserId = sessionData['requester_id'];
                  } else {
                    // If logged-in user is the requester, navigate to provider's profile
                    otherUserId = sessionData['provider_id'];
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserPage(userId: otherUserId),
                    ),
                  );
                } else {
                  // Show loading message if session data isn't available yet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Loading user data...'))
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: GoogleFonts.mulish(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.person_outline,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Text(
                      'Loading...',
                      style: GoogleFonts.mulish(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    )
                  else if (snapshot.hasError)
                    Text(
                      'Error loading skill info',
                      style: GoogleFonts.mulish(
                        color: Colors.red[100],
                        fontSize: 14,
                      ),
                    )
                  else
                    Text(
                      snapshot.data?['skillName'] ?? 'Unknown Skill',
                      style: GoogleFonts.mulish(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMessages,
            tooltip: 'Refresh messages',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF6296FF)),
            ),
          )
        : FutureBuilder<List<Map<String, dynamic>>>(
            future: messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF6296FF)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading messages\nPull to refresh',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mulish(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              final messagesList = snapshot.data ?? [];
              if (messagesList.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet\nStart the conversation!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mulish(
                      color: Colors.grey,
                      fontSize: 16,
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
                    child: _buildMessageBubble(message, isSentByUser),
                  );
                },
              );
            },
          );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isSentByUser) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSentByUser
              ? const Color(0xFF6296FF)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isSentByUser ? 20 : 5),
            bottomRight: Radius.circular(isSentByUser ? 5 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          message['message'],
          style: GoogleFonts.mulish(
            color: isSentByUser ? Colors.white : Colors.black87,
            fontSize: 15,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message['message'],
            style: GoogleFonts.mulish(
              color: Colors.black54,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
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
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF6296FF)),
            ),
          );
        }
        if (snapshot.hasData) {
          return _buildStateButton(snapshot.data!['status'], snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStateButton(String status, Map<String, dynamic> session) {
    // First determine user roles
    final bool isProvider = session['provider_id'].toString() == widget.loggedInUserId.toString();
    final bool isRequester = session['requester_id'].toString() == widget.loggedInUserId.toString();
    
    // If user is not part of this session, don't show any buttons
    if (!isProvider && !isRequester) {
      return const SizedBox.shrink();
    }
    
    // If user is the provider, show provider options
    if (isProvider) {
      switch (status) {
        case 'Requested':
          // Provider sees request acceptance button
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Service Request Pending Your Approval",
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleServiceAccept(session),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Accept',
                              style: GoogleFonts.mulish(
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Decline',
                              style: GoogleFonts.mulish(
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
          // Provider sees complete and cancel buttons
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleServiceComplete(session),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Complete',
                          style: GoogleFonts.mulish(
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Cancel',
                          style: GoogleFonts.mulish(
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
        case 'Cancelled':
        case 'Declined':
        default:
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: Text(
              "You are providing this service",
              textAlign: TextAlign.center,
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6296FF),
              ),
            ),
          );
      }
    }

    // Handle different session statuses for the requester
    switch (status) {
      case 'Idle':
        // Show Request Service button for requester in Idle state
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          color: Colors.white,
          child: ElevatedButton(
            onPressed: () => _handleServiceRequest(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6296FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.handshake_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Request Service',
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'Requested':
        // Show waiting message for requester
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.white,
          child: Text(
            "Service request sent. Waiting for provider to accept.",
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.orange[700],
            ),
          ),
        );

      case 'Pending':
        // Show requester buttons to confirm completion or cancel
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleServiceComplete(session),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Complete',
                        style: GoogleFonts.mulish(
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Cancel',
                        style: GoogleFonts.mulish(
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
        // Show completed message 
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.white,
          child: Text(
            "This service has been completed",
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        );

      case 'Cancelled':
        // Show cancelled message
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.white,
          child: Text(
            "This service was cancelled",
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
        );
        
      case 'Declined':
        // Show declined message
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.white,
          child: Text(
            "This service request was declined by the provider",
            textAlign: TextAlign.center,
            style: GoogleFonts.mulish(
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

  Future<void> _handleServiceRequest(Map<String, dynamic> session) async {
    try {
      // Show request dialog and wait for confirmation
      bool? result = await RequestService(session: session)
          .showRequestDialog(context);
          
      if (result == true) {
        try {
          // Get session ID
          final sessionId = session['id'];
          
          // Update the status to 'Requested' in database
          await supabase
              .from('sessions')
              .update({'status': 'Requested'})
              .eq('id', sessionId);
              
          // Add system message about the request
          await DatabaseHelper.sendMessage(
            widget.chatId,
            -1, // System message sender ID
            'Service requested. Waiting for provider to accept.',
          );
          
          // Add a notification for both requester and provider
          // to ensure tracking in the notifications area
          final requesterName = await _getUserName(session['requester_id']);
          final skillName = await _getSkillName(session['skill_id']);
          
          // Notify the provider
          await DatabaseHelper.createNotification(
            recipientId: int.parse(session['provider_id'].toString()),
            message: '$requesterName has requested your service: $skillName',
            senderId: int.parse(session['requester_id'].toString()),
          );
          
          // Reload the session and messages
          setState(() {
            _loadSession();
            _loadMessages();
          });
        } catch (e) {
          debugPrint('Error updating service status: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating service: $e'))
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to request service: $e'))
      );
    }
  }
  
  // Helper method to get a user's name
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
  
  // Helper method to get a skill's name
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
          'The Service Completion has been confirmed by ' + (session['provider_id'].toString() == widget.loggedInUserId.toString() ? 'the provider' : 'the requester') + '.',
        );
        setState(() {
          _loadSession();
          _loadMessages();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete service: $e'))
      );
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
          'The Service was Cancelled by ' + (session['provider_id'].toString() == widget.loggedInUserId.toString() ? 'the provider' : 'the requester') + '.',
        );
        setState(() {
          _loadSession();
          _loadMessages();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel service: $e'))
      );
    }
  }

  // Handle service acceptance by the provider
  Future<void> _handleServiceAccept(Map<String, dynamic> session) async {
    try {
      // Verify that the current user is the provider
      final loggedInUserId = await UserIdStorage.getLoggedInUserId();
      if (loggedInUserId == null) return;
      
      final isProvider = session['provider_id'].toString() == loggedInUserId.toString();
      if (!isProvider) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only the provider can accept service requests'),
            backgroundColor: Colors.red,
          )
        );
        return;
      }
      
      // Create instance of RequestService to use the accept dialog
      RequestService requestService = RequestService(session: session);
      
      // Show the accept dialog and wait for result
      final bool? result = await requestService.showAcceptDialog(context);
      
      if (result == true) {
        // Refresh the page to show updated status
        setState(() {
          messages = _initializeMessages();
        });
      }
    } catch (e) {
      debugPrint('Error accepting service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Handle service declination by the provider
  Future<void> _handleServiceDecline(Map<String, dynamic> session) async {
    try {
      // Create instance of RequestService to use the accept dialog (which has decline functionality)
      RequestService requestService = RequestService(session: session);
      
      // Show the accept dialog and wait for result
      final bool? result = await requestService.showAcceptDialog(context);
      
      // Refresh the page even if declined
      setState(() {
        messages = _initializeMessages();
      });
    } catch (e) {
      debugPrint('Error declining service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.mulish(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.mulish(),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF6296FF),
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _handleSendMessage,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
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

  Future<Map<String, dynamic>> _loadSession() async {
    try {
      // Get the chat info with session_id
      final chatData = await supabase
          .from('chats')
          .select('session_id, user1_id, user2_id')
          .eq('id', widget.chatId)
          .single();
          
      if (chatData == null || !chatData.containsKey('session_id')) {
        throw Exception('No session found for this chat');
      }
      
      // Get the session data without any auto-request logic
      final sessionData = await supabase
          .from('sessions')
          .select()
          .eq('id', chatData['session_id'])
          .single();
      
      // Store session for later use but don't take any actions on it
      session = sessionData;
      
      // Just return the raw data, don't modify it or trigger any services
      return sessionData;
    } catch (err) {
      debugPrint('Error loading session: $err');
      return {'status': 'Idle', 'provider_id': 0, 'requester_id': 0, 'skill_id': 0};
    }
  }

  Future<Map<String, dynamic>> _loadSessionAndSkill() async {
    try {
      // Get session data for this chat
      final chatData = await supabase
          .from('chats')
          .select('session_id, user1_id, user2_id')
          .eq('id', widget.chatId)
          .single();
      
      if (chatData == null || !chatData.containsKey('session_id')) {
        throw Exception('No session found for this chat');
      }
      
      // Get the session and user data in parallel
      final sessionFuture = supabase
          .from('sessions')
          .select('*, skills!inner(*)')
          .eq('id', chatData['session_id'])
          .single();
          
      // Determine the other user ID
      final otherUserId = chatData['user1_id'].toString() == widget.loggedInUserId.toString()
          ? chatData['user2_id']
          : chatData['user1_id'];
          
      // Get the other user's info
      final userFuture = supabase
          .from('users')
          .select('username, avatar_url')
          .eq('id', otherUserId)
          .single();
          
      // Wait for both futures to complete
      final results = await Future.wait([sessionFuture, userFuture]);
      final sessionData = results[0];
      final userData = results[1];
      
      return {
        'skillName': sessionData['skills']['name'] ?? 'Unknown Skill',
        'session': sessionData,
        'otherUsername': userData['username'] ?? 'Unknown User'
      };
    } catch (err) {
      debugPrint('Error loading session data: $err');
      return {
        'skillName': 'Unknown Skill',
        'session': {},
        'otherUsername': 'Unknown User'
      };
    }
  }

  Future<void> _fetchSessionData() async {
    try {
      final sessionData = await _loadSession();
      setState(() {
        session = sessionData;
      });
    } catch (e) {
      debugPrint('Error fetching session data: $e');
    }
  }
}
