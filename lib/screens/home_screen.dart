// screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/item_model.dart';
import 'detail_screen.dart';
import 'add_item_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'edit_item_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'privacy_policy_screen.dart';
import '../services/app_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State variables
  List<ItemModel> _items = [];
  int _selectedTab = 0;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _notificationCount = 0;
  int _unreadMessagesCount = 0;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final AppService _appService = AppService();

  // User data
  String _displayName = 'User';
  String _username = '@user';
  String _userEmail = '';
  String _userId = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Immediately load cached local items so UI renders in 0ms!
    final localCached = await _appService.getCachedItemsLocal();
    if (mounted) {
      setState(() {
        _items = localCached;
        _isLoading = false;
      });
    }

    // 2. Load user profile & counts concurrently in background
    _loadUserProfile();
    _fetchCounts();

    // 3. Silently fetch fresh items in background
    _syncFreshItems();
  }

  Future<void> _syncFreshItems() async {
    try {
      final fresh = await _appService.getAllItems();
      if (mounted && fresh.isNotEmpty) {
        setState(() {
          _items = fresh;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUser = await _appService.getCurrentUser();
      if (currentUser != null) {
        if (mounted) {
          setState(() {
            _displayName = currentUser.displayName.isNotEmpty
                ? currentUser.displayName
                : 'User';
            _username = currentUser.username.isNotEmpty
                ? '@${currentUser.username}'
                : '@user';
            _userEmail = currentUser.email;
            _userId = currentUser.id;
            _profileImageUrl = currentUser.profileImage.isNotEmpty
                ? currentUser.profileImage
                : null;
          });
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (mounted) {
          setState(() {
            _displayName = prefs.getString('displayName') ?? prefs.getString('current_user_name') ?? 'User';
            _username = '@${prefs.getString('username') ?? 'user'}';
            _userEmail = prefs.getString('email') ?? prefs.getString('current_user_email') ?? '';
            _profileImageUrl = prefs.getString('current_user_image');
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadItems() async {
    final cached = await _appService.getCachedItemsLocal();
    if (mounted) {
      setState(() {
        _items = cached;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
    await _syncFreshItems();
  }

  Future<void> _fetchCounts() async {
    try {
      final currentUserId = _appService.currentUserId;
      if (currentUserId == null) return;

      final notificationCount = await _appService.getNotificationCount(currentUserId);
      final unreadMessagesCount = await _appService.getUnreadMessagesCount(currentUserId);

      if (mounted) {
        setState(() {
          _notificationCount = notificationCount;
          _unreadMessagesCount = unreadMessagesCount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching counts: $e');
    }
  }

  Future<void> _refreshItems() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }
    await _loadItems();
    await _fetchCounts();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  List<ItemModel> _getFilteredItems() {
    List<ItemModel> filtered = _items;

    switch (_selectedTab) {
      case 1:
        filtered = filtered.where((item) => item.isLost).toList();
        break;
      case 2:
        filtered = filtered.where((item) => !item.isLost).toList();
        break;
      case 3:
        filtered = filtered.where((item) {
          final uploaderId = item.uploaderId.toLowerCase();
          final uploaderName = item.uploader.toLowerCase();
          final curUserId = _userId.toLowerCase();
          final curEmail = _userEmail.toLowerCase();
          final curName = _displayName.toLowerCase();

          if (curUserId.isNotEmpty && uploaderId == curUserId) return true;
          if (curEmail.isNotEmpty && uploaderId == curEmail) return true;
          if (curName.isNotEmpty && uploaderName == curName) return true;
          if (uploaderId == 'guest' || uploaderId == 'user_local' || uploaderId.startsWith('user_')) return true;
          return false;
        }).toList();
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.location.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _appService.logout();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'Are you sure you want to delete this item? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _appService.deleteItem(itemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildChatIconWithCount() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.chat, color: Colors.white),
        ),
        if (_unreadMessagesCount > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadMessagesCount > 9
                    ? '9+'
                    : _unreadMessagesCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                Scaffold.of(context).openDrawer();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const Text(
                          'CUI Trace',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatListScreen(),
                              ),
                            ).then((_) => _fetchCounts());
                          },
                          child: _buildChatIconWithCount(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'COMSATS University Sahiwal',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search items, location or categories',
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.blue,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                              : null,
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('All', 0, Icons.all_inclusive),
                  const SizedBox(width: 10),
                  _buildFilterTab('Lost', 1, Icons.search),
                  const SizedBox(width: 10),
                  _buildFilterTab('Found', 2, Icons.find_in_page),
                  const SizedBox(width: 10),
                  _buildFilterTab('My Reports', 3, Icons.person),
                ],
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshItems,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddItemScreen()),
        ).then((_) => _refreshItems()),
        icon: const Icon(Icons.add),
        label: const Text('Add Report'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  ImageProvider? _getDrawerAvatarImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return CachedNetworkImageProvider(imagePath);
    }
    final file = File(imagePath);
    if (file.existsSync() || imagePath.startsWith('/') || imagePath.contains('\\') || imagePath.contains(':')) {
      return FileImage(file);
    }
    return null;
  }

  Widget _buildDrawer() {
    final avatarProvider = _getDrawerAvatarImage(_profileImageUrl);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_userEmail),
            currentAccountPicture: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      _displayName.isNotEmpty
                          ? _displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    )
                  : null,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'My Profile',
                  count: null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                          currentName: _displayName,
                          currentEmail: _userEmail,
                          currentImageUrl: _profileImageUrl,
                        ),
                      ),
                    ).then((_) => _loadUserProfile());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.description,
                  title: 'My Reports',
                  count: _items.where((e) => e.uploaderId == _userId).length,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 3);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.chat,
                  title: 'Messages',
                  count: _unreadMessagesCount,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    ).then((_) => _fetchCounts());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  count: _notificationCount,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ).then((_) => _fetchCounts());
                  },
                ),
                const Divider(height: 20),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  count: null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.help,
                  title: 'Help & Support',
                  count: null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  count: null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(50),
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    int? count,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: count != null && count > 0
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildFilterTab(String title, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredItems = _getFilteredItems();

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) => _buildItemCard(filteredItems[index]),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    if (_searchQuery.isNotEmpty) {
      message = 'No items found for "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_selectedTab == 3) {
      message = 'You have no reports';
      icon = Icons.description;
    } else if (_selectedTab == 1) {
      message = 'No lost items found';
      icon = Icons.search;
    } else if (_selectedTab == 2) {
      message = 'No found items found';
      icon = Icons.find_in_page;
    } else {
      message = 'No items available';
      icon = Icons.inventory;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        color: Colors.blue.shade50,
        child: Icon(Icons.image_not_supported, size: 48, color: Colors.blue.shade300),
      );
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => Container(
          color: Colors.blue.shade50,
          child: Icon(Icons.broken_image, size: 48, color: Colors.blue.shade300),
        ),
      );
    }
    final file = File(imageUrl);
    return Image.file(
      file,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.blue.shade50,
        child: Icon(Icons.broken_image, size: 48, color: Colors.blue.shade300),
      ),
    );
  }

  Widget _buildItemCard(ItemModel item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: _buildCardImage(item.imageUrl),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'By: ${item.uploader}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.location,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.uploaderId == _userId) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditItemScreen(
                                    item: item,
                                    itemId: item.id,
                                  ),
                                ),
                              ).then((_) => _refreshItems()),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item.id),
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: const Text('Message', style: TextStyle(fontSize: 12)),
                              onPressed: () => _startDirectChat(item),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: item.isLost ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  item.isLost ? 'Lost' : 'Found',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDirectChat(ItemModel item) async {
    final currentUserId = _appService.currentUserId ?? _userId ?? '';
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to send message')),
      );
      return;
    }
    if (item.uploaderId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own report')),
      );
      return;
    }
    final res = await _appService.createOrGetChat(
      currentUserId: currentUserId,
      otherUserId: item.uploaderId,
      otherUserName: item.uploader,
      itemId: item.id,
      itemTitle: item.title,
    );
    final chatId = res['chatId']?.toString() ?? '';
    if (mounted && chatId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: item.uploaderId,
            otherUserName: item.uploader,
            itemId: item.id,
            itemTitle: item.title,
          ),
        ),
      );
    }
  }
}
