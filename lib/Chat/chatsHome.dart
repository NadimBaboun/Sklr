import 'package:flutter/material.dart';
import '../database/database.dart';
import 'chat.dart';
import '../Util/navigationbar-bar.dart';
import '../database/userIdStorage.dart';

class ChatsHomePage extends StatefulWidget {
  const ChatsHomePage({super.key});

  @override
  _ChatsHomePageState createState() => _ChatsHomePageState();
}

class _ChatsHomePageState extends State<ChatsHomePage> {
  int? loggedInUserId;
  Future<List<Map<String, dynamic>>>? chatsFuture;
  Map<int, String> usernameCache = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndChats();
  }

  Future<void> _loadUserIdAndChats() async {
    setState(() => isLoading = true);
    try {
      final userId = await UserIdStorage.getLoggedInUserId();
      if (userId != null) {
        setState(() => loggedInUserId = userId);
        final chats = await DatabaseHelper.fetchChats(userId);
        await _cacheUsernames(chats);
        setState(() => chatsFuture = Future.value(chats));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cacheUsernames(List<Map<String, dynamic>> chats) async {
    for (var chat in chats) {
      final otherUserId = chat['other_user_id'];
      if (!usernameCache.containsKey(otherUserId)) {
        final response = await DatabaseHelper.fetchUserFromId(otherUserId);
        usernameCache[otherUserId] =
            response.success ? response.data['username'] : 'Unknown';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(158),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF6296FF),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 27, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined, color: Colors.white),
                  onPressed: _loadUserIdAndChats,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingState();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: chatsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoadingState();
        if (snapshot.data!.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) =>
              _buildChatTile(snapshot.data![index]),
        );
      },
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final otherUserId = chat['other_user_id'];
    final username = usernameCache[otherUserId] ?? 'Loading...';
    final lastMessage = chat['last_message'] ?? 'No messages yet.';
    final lastUpdated = chat['last_updated']?.toString().substring(0, 10) ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFFFC7C7),
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF262933),
          ),
        ),
        subtitle: Text(
          lastMessage,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          lastUpdated,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatId: chat['chat_id'],
              loggedInUserId: loggedInUserId!,
              otherUsername: username,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6296FF)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No messages yet',
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
