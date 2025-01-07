import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String backendUrl = 'http://localhost:3000/api/chat';



class ChatPage extends StatefulWidget {
  final int chatId;
  final int loggedInUserId;

  const ChatPage({super.key, required this.chatId, required this.loggedInUserId});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>{
  late Future<List<Map<String, dynamic>>> messages;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState(){
    super.initState();
    messages = fetchMessages(widget.chatId);
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async{
    final response = await http.get(Uri.parse('$backendUrl/$chatId/messages'));

    if(response.statusCode == 200){
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    else{
      throw Exception('Failed to load messages');
    }
  }

  Future<void> _sendMessage(int chatId, int senderId, String message) async {
    final response = await http.post(Uri.parse('$backendUrl/$chatId/message'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'senderId': senderId, 'message': message}),
    );

    if(response.statusCode != 200){
      throw Exception('Failed to send message');
    }    
  }

  void _handleSendMessage() async{
    if(_messageController.text.trim().isNotEmpty) {
      await _sendMessage(widget.chatId, widget.loggedInUserId, _messageController.text.trim());
      setState(() {
        messages = fetchMessages(widget.chatId);
      });
      _messageController.clear();
    }
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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

                    return Align(
                      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSentByUser ? Colors.blue : Colors.grey[300],
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
}