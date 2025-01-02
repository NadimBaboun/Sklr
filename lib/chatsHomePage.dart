import 'package:flutter/material.dart';
import 'package:sklr/database/database.dart';
import 'chatPage.dart';


class ChatsHomePage extends StatelessWidget{
  final int loggedInUserId;

  const ChatsHomePage({super.key, required this.loggedInUserId});

@override
Widget build(BuildContext context){
  return Scaffold(
    appBar: AppBar(
      title: const Text('Chats'),
      centerTitle: true,
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.fetchUserChats(loggedInUserId),
      builder: (context, snapshot){
        if(!snapshot.hasData)
        {
          return const Center(child: CircularProgressIndicator());
        }
        if(snapshot.data!.isEmpty){
          return const Center(child: Text('No chats found.'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index){
            final chat = snapshot.data![index];
            final otherUserId = chat['other_user_id'];
            final lastMessage = chat['last_message'] ?? 'No messages yet.';

            return ListTile(
              leading: CircleAvatar(
                child: Text(otherUserId.toString()),
              ),
              title: Text('User $otherUserId'),
              subtitle: Text(lastMessage),
              trailing: Text(
                chat['last_updated'] != null ? chat['last_updated'].toString().substring(0,10) : '',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ChatPage(chatId: chat['chat_id'], loggedInUserId: loggedInUserId)
                ));
              },
            );
          },
        );
      },
    )
  );
}

}