import 'package:flutter/material.dart';
import 'database/database.dart';
import 'chatPage.dart';
import 'navigationbar-bar.dart';
import 'database/userIdStorage.dart';

class ChatsHomePage extends StatefulWidget{

  const ChatsHomePage({super.key});

  @override
  _ChatsHomePageState createState() => _ChatsHomePageState();


}

class _ChatsHomePageState extends State<ChatsHomePage>{
  int? loggedInUserId;
  Future<List<Map<String, dynamic>>>? chatsFuture;
  Map<int, String> usernameCache = {};

  @override
  void initState(){
    super.initState();
    _loadUserIdAndChats();
  }

  Future<void> _loadUserIdAndChats() async{
    final userId = await UserIdStorage.getLoggedInUserId();
    if(userId != null){
      setState(() {
        loggedInUserId = userId;
      });
      final chats = await DatabaseHelper.fetchChats(userId);
      for(var chat in chats){
        final otherUserId = chat['other_user_id'];

        if(!usernameCache.containsKey(otherUserId)){
          final response = await DatabaseHelper.fetchUserFromId(otherUserId);
          
          if(response.success){
            usernameCache[otherUserId] = response.data['username'];
          }
          else{
            usernameCache[otherUserId] = 'Unknown';
          }
        }
      }
      setState(() {
        chatsFuture = Future.value(chats);
      });
    } 
  }

  @override
  Widget build(BuildContext context){
    if(loggedInUserId == null){
      return Scaffold(
        appBar:AppBar(
          title: const Text('Chats'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        )
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: chatsFuture,
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
            itemBuilder: (context, index) {
              final chat = snapshot.data![index];
              final otherUserId = chat['other_user_id'];
              final lastMessage = chat['last_message'] ?? 'No messages yet.';
              final skillName = chat['skill'];
              final username = usernameCache[otherUserId] ?? 'Loading...';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(username.isNotEmpty ? username[0] : '?'),
                ),
                title: Text(
                  '$username ($skillName)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis
                ),
                subtitle: Text(lastMessage, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Text(
                  chat['last_updated'] != null ? chat['last_updated'].toString().substring(0,10) : '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ChatPage(chatId: chat['chat_id'], loggedInUserId: loggedInUserId!, otherUsername: usernameCache[otherUserId] ?? 'Unknown')
                  ));
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 1),
    );
  }
}