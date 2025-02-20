import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/Chat/chatSessionUtil.dart';
import '../database/database.dart';

class ChatPage extends StatefulWidget {
  final int chatId;
  final int loggedInUserId;
  final String otherUsername;

  const ChatPage(
      {super.key,
      required this.chatId,
      required this.loggedInUserId,
      required this.otherUsername});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<List<Map<String, dynamic>>> messages;
  final TextEditingController _messageController = TextEditingController();
  bool isLoading = false;
  late Map<String, dynamic> session;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => isLoading = true);
    messages = DatabaseHelper.fetchMessages(widget.chatId);
    setState(() => isLoading = false);
  }

  void _handleSendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      setState(() => isLoading = true);
      await DatabaseHelper.sendMessage(
          widget.chatId, widget.loggedInUserId, messageText);
      _messageController.clear();
      await _loadMessages();
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildSessionStatus(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(85),
      child: AppBar(
        elevation: 2,
        backgroundColor: const Color(0xFF6296FF),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.otherUsername,
          style: GoogleFonts.inter(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadMessages,
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: _buildSkillHeader(),
        ),
      ),
    );
  }

  Widget _buildSkillHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadSessionAndSkill(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Text(
              'Error loading skill',
              style: GoogleFonts.inter(color: Colors.white70),
            );
          }
          final skillName = snapshot.data?['skillName'] ?? 'Unknown Skill';
          return Text(
            skillName,
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : FutureBuilder<List<Map<String, dynamic>>>(
            future: messages,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(15),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final message = snapshot.data![index];
                  return _buildMessageBubble(message);
                },
              );
            },
          );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final bool isSentByUser = message['sender_id'] == widget.loggedInUserId;

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
          bottom: 10,
          left: isSentByUser ? 50 : 0,
          right: isSentByUser ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSentByUser ? const Color(0xFF6296FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          message['message'],
          style: GoogleFonts.inter(
            color: isSentByUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            message['message'],
            style: GoogleFonts.inter(
              color: Colors.grey[800],
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
          return const CircularProgressIndicator();
        }
        if (snapshot.hasData) {
          return _buildStateButton(snapshot.data!['status'], snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStateButton(String status, Map<String, dynamic> session) {
    if (session['provider_id'] == widget.loggedInUserId) {
      return Center(
        child: Text(
          "You are providing this service!",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    switch (status) {
      case 'Idle':
        return Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.handshake_outlined, color: Colors.white),
            onPressed: () async {
              bool? result = await RequestService(session: session)
                  .showRequestDialog(context);
              if (result == true) {
                await DatabaseHelper.sendMessage(
                    widget.chatId, -1, 'The Service was Requested!');
                setState(() {
                  _loadSession();
                  _loadMessages();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6296FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            label: Text(
              'Request Service',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );

      case 'Pending':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon:
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                onPressed: () async {
                  bool? result = await CompleteService(session: session)
                      .showFinalizeDialog(context);
                  if (result == true) {
                    await DatabaseHelper.sendMessage(
                        widget.chatId, -1, 'The Service was Completed!');
                    setState(() {
                      _loadSession();
                      _loadMessages();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF228B22),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                label: Text(
                  'Complete',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                onPressed: () async {
                  bool? result = await CancelService(session: session)
                      .showFinalizeDialog(context);
                  if (result == true) {
                    await DatabaseHelper.sendMessage(
                        widget.chatId, -1, 'The Service was Cancelled!');
                    setState(() {
                      _loadSession();
                      _loadMessages();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: const Color(0xFF6296FF),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _handleSendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadSession() async {
    try {
      final response = await DatabaseHelper.fetchSessionFromChat(widget.chatId);
      if (!response.success) throw Exception('Failed to fetch session');
      return response.data;
    } catch (err) {
      throw Exception('Error loading session: $err');
    }
  }

  Future<Map<String, dynamic>> _loadSessionAndSkill() async {
    try {
      final sessionResponse =
          await DatabaseHelper.fetchSessionFromChat(widget.chatId);
      if (!sessionResponse.success) throw Exception('Failed to fetch session');

      final skillResponse =
          await DatabaseHelper.fetchOneSkill(sessionResponse.data['skill_id']);
      if (skillResponse.isEmpty) throw Exception('Failed to fetch skill');

      return {
        'skillName': skillResponse['name'],
        'session': sessionResponse.data
      };
    } catch (err) {
      throw Exception('Error loading data: $err');
    }
  }
}
