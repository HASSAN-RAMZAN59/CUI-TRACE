// screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'edit_profile_screen.dart';
import '../services/app_service.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const ProfileScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppService _appService = AppService();

  UserModel? _currentUser;
  Map<String, dynamic>? _userData;
  List<ItemModel> _userItems = [];
  bool _loading = true;

  bool get _isViewingOwnProfile =>
      widget.targetUserId == null ||
          widget.targetUserId == _appService.currentUserId;

  String get _viewingUserId =>
      _isViewingOwnProfile ? _appService.currentUserId ?? '' : widget.targetUserId!;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (_isViewingOwnProfile) {
        final user = await _appService.getCurrentUser();
        if (user != null) {
          final items = await _appService.getUserItems(user.id);
          setState(() {
            _currentUser = user;
            _userData = {
              'displayName': user.displayName,
              'email': user.email,
              'username': user.username,
              'createdAt': user.createdAt,
            };
            _userItems = items;
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } else {
        final items = await _appService.getUserItems(widget.targetUserId!);
        setState(() {
          _userData = {
            'displayName': widget.targetUserName ?? 'User',
            'email': '',
            'createdAt': DateTime.now(),
          };
          _userItems = items;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _appService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    await _loadUserData();
  }

  Widget _buildProfileHeader() {
    final displayName =
        _userData?['displayName'] ?? widget.targetUserName ?? 'User';
    final email = _userData?['email'] ?? '';
    final phone = _userData?['phoneNumber'] ?? '';
    final profileImage = _userData?['profileImage'] ?? '';
    final joinedDate = _userData?['createdAt'] is DateTime
        ? _userData!['createdAt'] as DateTime
        : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade100,
            backgroundImage:
            profileImage.isNotEmpty ? CachedNetworkImageProvider(profileImage) : null,
            child: profileImage.isEmpty
                ? Icon(Icons.person, size: 50, color: Colors.blue.shade400)
                : null,
          ),
          const SizedBox(height: 16),
          Text(displayName,
              style:
              const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: Colors.grey.shade600)),
          if (phone.isNotEmpty) Text(phone),
          const SizedBox(height: 8),
          Text(
            'Member since ${DateFormat('MMM yyyy').format(joinedDate)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          if (_isViewingOwnProfile)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            currentName: displayName,
                            currentEmail: email,
                            currentImageUrl:
                            profileImage.isNotEmpty ? profileImage : null,
                          ),
                        ),
                      ).then((v) {
                        if (v == true) _refreshData();
                      });
                    },
                    child: const Text('Edit Profile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _signOut,
                    style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final lostCount = _userItems.where((i) => i.isLost).length;
    final foundCount = _userItems.where((i) => !i.isLost).length;
    final totalCount = _userItems.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Lost Items', lostCount, Colors.orange),
          _statItem('Found Items', foundCount, Colors.green),
          _statItem('Total Reports', totalCount, Colors.blue),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style:
            TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isViewingOwnProfile
            ? 'My Profile'
            : '${_userData?['displayName'] ?? widget.targetUserName}\'s Profile'),
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildStatsCard(),
            ],
          ),
        ),
      ),
    );
  }
}