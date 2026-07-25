import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AppService _appService = AppService();

  UserModel? _currentUser;
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadCurrentUser();
    } catch (e) {
      print('Error initializing app: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _appService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _loading = false;
      });
    } catch (e) {
      print('Error loading current user: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading chats...'),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 60),
              SizedBox(height: 16),
              Text(
                'Please login to view messages',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _appService.getUserChatsStream(_currentUser!.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a chat with someone',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          List<Map<String, dynamic>> chats = snapshot.data!;

          if (_searchQuery.isNotEmpty) {
            final lowerCaseQuery = _searchQuery.toLowerCase();
            chats = chats.where((chat) {
              final name = (chat['otherUserName'] ?? '').toString().toLowerCase();
              final msg = (chat['lastMessage'] ?? '').toString().toLowerCase();
              return name.contains(lowerCaseQuery) || msg.contains(lowerCaseQuery);
            }).toList();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              itemCount: chats.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _buildChatItem(chat);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final chatId = chat['id'] ?? '';
    final otherUserId = chat['otherUserId'] ?? '';
    final otherUserName = chat['otherUserName'] ?? 'Unknown';
    final otherUserImage = chat['otherUserImage'] ?? '';
    final lastMessage = chat['lastMessage'] ?? '';
    final lastMessageTime = chat['lastMessageTime'] as DateTime? ?? DateTime.now();
    final unread = chat['unread'] ?? false;

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: otherUserImage.isNotEmpty
            ? CachedNetworkImageProvider(otherUserImage) as ImageProvider<Object>?
            : null,
        child: otherUserImage.isEmpty
            ? Text(
          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.blue),
        )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserName,
              style: TextStyle(
                fontWeight: unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (unread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        lastMessage,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
          color: unread ? Colors.black : Colors.grey,
        ),
      ),
      trailing: Text(
        _formatTime(lastMessageTime),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chatDate = DateTime(time.year, time.month, time.day);

    if (chatDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}