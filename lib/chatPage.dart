import 'package:flutter/material.dart';
import 'database/database.dart';


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
    messages = DatabaseHelper.fetchMessages(widget.chatId);
  }

  void _handleSendMessage() async{
    if(_messageController.text.trim().isNotEmpty) {
      await DatabaseHelper.sendMessage(widget.chatId, widget.loggedInUserId, _messageController.text.trim());
      setState(() {
        messages = DatabaseHelper.fetchMessages(widget.chatId);
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