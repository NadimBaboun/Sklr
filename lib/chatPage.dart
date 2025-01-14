import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/chatSessionUtil.dart';
import 'database/database.dart';


const String backendUrl = 'http://localhost:3000/api/chat';



class ChatPage extends StatefulWidget {
  final int chatId;
  final int loggedInUserId;
  final String otherUsername;

  const ChatPage({super.key, required this.chatId, required this.loggedInUserId, required this.otherUsername});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>{
  late Future<List<Map<String, dynamic>>> messages;
  final TextEditingController _messageController = TextEditingController();
  bool isLoading = false;
  late Map<String, dynamic> session;

  @override
  void initState(){
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      isLoading = true;
    });
    messages = DatabaseHelper.fetchMessages(widget.chatId);
    setState(() {
      isLoading = false;
    });
  }

  void _handleSendMessage() async{
    if(_messageController.text.trim().isNotEmpty) {
      await DatabaseHelper.sendMessage(widget.chatId, widget.loggedInUserId, _messageController.text.trim());
      setState(() {
        messages = DatabaseHelper.fetchMessages(widget.chatId);
      });
      _messageController.clear();
      await _loadMessages();
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: const Color(0xFF6296FF),
          title: Text(widget.otherUsername,
          style: TextStyle(
            color: Colors.white
          )),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Container(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _loadSessionAndSkill(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final skillName = snapshot.data!['skillName'] ?? 'Unknown Skill';
                    return Text(skillName,
                    style: TextStyle(
                      color: Colors.white
                    ));
                  } else {
                    return const Center(
                      child: Text('No data available')
                    );
                  }
                }
              )
            )
          )
        )
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading ? const Center(child: CircularProgressIndicator()) : FutureBuilder<List<Map<String, dynamic>>>(
              future: messages,
              builder: (context, snapshot) {
                if(!snapshot.hasData){
                  return const Center(child: CircularProgressIndicator());
                }
                if(snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index){
                    final message = snapshot.data![index];
                    final isSentByUser = message['sender_id'] == widget.loggedInUserId;
                    
                    if (message['sender_id'] == -1) {
                      return Align(
                        alignment: Alignment.center,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message['message'],
                            style: TextStyle(
                              color: Colors.black,
                            )
                          )
                        )
                      );
                    }

                    return Align(
                      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSentByUser ? Color(0xFF6296FF) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          message['message'],
                          style: TextStyle(
                            color: isSentByUser ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _loadSession(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              else if (snapshot.hasData) {
                final status = snapshot.data!['status'];
                return _buildStateButton(status, snapshot.data!);
              } else {
                return const SizedBox(height: 0);
              }
            }
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSendMessage,
                ),
              ],
            )
          )
        ],
      )
    );
  }

  Future<Map<String, dynamic>> _loadSession() async {
    try {
      final response = await DatabaseHelper.fetchSessionFromChat(widget.chatId);
      if (!response.success) {
        throw Exception('Failed to fetch session');
      }
      return response.data;
    } catch (err) {
      throw Exception('Error loading session: $err');
    }
  }

  Widget _buildStateButton(String status, Map<String, dynamic> session) {
    if (session['provider_id'] == widget.loggedInUserId) {
      return Center(
        child: Text("You are providing this service!")
      );
    }
    switch (status) {
      case 'Idle': // request service button
        return Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.handshake_outlined, color: Colors.white),
            onPressed: () async {
              // Open the dialog through RequestService
              bool? result = await RequestService(session: session).showRequestDialog(context);

              if (result == true) {
                // append request message
                await DatabaseHelper.sendMessage(widget.chatId, -1, 'The Service was Requested!');
                setState(() {
                  _loadSession();
                  _loadMessages();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6296FF)
            ),
            label: Text('Request Service', style: GoogleFonts.mulish(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      case 'Pending': // complete service button, cancel session button
        return Column(
          children: [
            Center( // complete service button
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                onPressed: () async {
                  // Open the dialog through CompleteService
                  bool? result = await CompleteService(session: session).showFinalizeDialog(context);

                  if (result == true) {
                    // append complete message
                    await DatabaseHelper.sendMessage(widget.chatId, -1, 'The Service was Completed!');
                    setState(() {
                      _loadSession();
                      _loadMessages();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF228B22)
                ),
                label: Text('Complete', style: GoogleFonts.mulish(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                onPressed: () async {
                  // Open the dialog through CancelService
                  bool? result = await CancelService(session: session).showFinalizeDialog(context);

                  if (result == true) {
                    await DatabaseHelper.sendMessage(widget.chatId, -1, 'The Service was Cancelled!');
                    setState(() {
                      _loadSession();
                      _loadMessages();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                label: Text('Cancel', style: GoogleFonts.mulish(color: Colors.white, fontWeight: FontWeight.w600)),
              )
            )
          ]
        );
      default:
        return const Center(child: Text('Null'));
    }
  }

  Future<Map<String, dynamic>> _loadSessionAndSkill() async {
    try {
      final sessionResponse = await DatabaseHelper.fetchSessionFromChat(widget.chatId);
      if (!sessionResponse.success) {
        throw Exception('Failed to fetch session');
      }
      final session = sessionResponse.data;
      
      final skillResponse = await DatabaseHelper.fetchOneSkill(session['skill_id']);
      if (skillResponse.isEmpty) {
        throw Exception('Failed to fetch skill');
      }

      return {'skillName': skillResponse['name'], 'session': session};
    } catch (err) {
      throw Exception('Error loading data: $err');
    }
  }
}
