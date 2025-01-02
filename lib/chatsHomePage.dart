import 'package:/flutter/material.dart';
import 'chatPage.dart';


class ChatsHomePage extends StatefulWidget {
  final int loggedInUserId;

  const ChatsHomePage({super.key, required this.loggedInUserId});

  @override
  _ChatsHomePageState createState() => _ChatsHomePageState();
}

class _ChatsHomePageState extends State<ChatsHomePage> {
  late Future<List<Map<String, dynamic>>> userChats;




/*
@override
void initState() {
  super.initState();
  userChats = fetchChats();
}
*/

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Chats'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: userChats,
        builder: (context, snapshot) {
          if(!snapshot.hasData){
            return const Center(child: CircularProgressIndicator());
          }
          if(snapshot.data!.isEmpty){
            return const Center(child: Text('No chats yet.'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index){
              final chat = snapshot.data![index];
              return ListTile(
                title: Text('Chat with User ${chat['other_user_id']}'),
                subtitle: Text(chat['last_message'] ?? 'No messages yet.'),
                trailing: Text(
                  chat['last_updated'] != null ? chat['last_updated'].toString().substring(0, 10) : '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ChatPage(chatId: chat['id'], loggedInUserId: widget.loggedInUserId,
                  ),
                  ),
                );
                } ,
              );
            },
          );
        }
      )
    );
  }
}