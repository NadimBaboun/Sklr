import 'package:/flutter/material.dart';



class ChatPage extends StatefulWidget {
  final int chatId;
  final int loggedInUserId;

  const ChatPage({super.key, required this.chatId, required this.loggedInUserId});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>{
  
}