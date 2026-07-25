// screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/item_model.dart';
import '../services/app_service.dart';
import 'verification_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final AppService _appService = AppService();
  String _currentUserId = '';
  bool _loading = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _checkVerificationStatus();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _appService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_currentUserId.isEmpty || !widget.item.requiresVerification) return;

    try {
      final canAttempt = await _appService.canUserAttemptVerification(widget.item.id, _currentUserId);
      if (mounted) {
        setState(() {
          _isVerified = !canAttempt;
        });
      }
    } catch (e) {
      print('Error checking verification: $e');
    }
  }

  Future<String> _getOrCreateChatId(String otherUserId) async {
    if (_currentUserId.isEmpty) return '';

    try {
      final result = await _appService.createOrGetChat(
        currentUserId: _currentUserId,
        otherUserId: otherUserId,
        otherUserName: widget.item.uploader,
        itemId: widget.item.id,
        itemTitle: widget.item.title,
      );
      return result['chatId']?.toString() ?? '';
    } catch (e) {
      print('Error creating/retrieving chat: $e');
      return '';
    }
  }

  Future<void> _navigateToVerification() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(item: widget.item),
      ),
    );

    if (result == true && mounted) {
      await _checkVerificationStatus();
      _showContactOptions();
    }
  }

  Future<void> _startChat() async {
    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to start chat')),
      );
      return;
    }

    if (widget.item.uploaderId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself')),
      );
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      final chatId = await _getOrCreateChatId(widget.item.uploaderId);

      if (chatId.isEmpty) {
        throw Exception('Failed to create chat');
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });

        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': chatId,
            'otherUserId': widget.item.uploaderId,
            'otherUserName': widget.item.uploader,
            'itemId': widget.item.id,
            'itemTitle': widget.item.title,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Contact Uploader',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (widget.item.requiresVerification)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _isVerified ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isVerified ? Colors.green.shade200 : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isVerified ? Icons.verified : Icons.verified_outlined,
                        color: _isVerified ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isVerified
                              ? '✅ Verified Owner - You can contact uploader'
                              : '🔒 Verification required to contact',
                          style: TextStyle(
                            color: _isVerified ? Colors.green.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.chat, color: Colors.blue),
                title: const Text('Start Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _startChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.orange),
                title: const Text('Report Item'),
                onTap: () {
                  Navigator.pop(context);
                  _reportItem();
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactButton() {
    final isCurrentUser = widget.item.uploaderId == _currentUserId;

    if (isCurrentUser) {
      return ElevatedButton.icon(
        onPressed: () => _showVerificationAttempts(),
        icon: const Icon(Icons.visibility),
        label: const Text('View Verification Attempts'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    if (widget.item.isClaimed) {
      return const OutlinedButton(
        onPressed: null,
        child: Text('Already Claimed'),
      );
    }

    if (widget.item.requiresVerification && widget.item.securityQuestions.isNotEmpty) {
      if (_isVerified) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.verified_user),
          label: const Text(
            'Contact Uploader',
            style: TextStyle(fontSize: 16),
          ),
          onPressed: _showContactOptions,
        );
      } else {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.verified_outlined),
          label: const Text(
            'Verify to Contact',
            style: TextStyle(fontSize: 16),
          ),
          onPressed: _navigateToVerification,
        );
      }
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.message),
        label: const Text(
          'Contact Uploader',
          style: TextStyle(fontSize: 16),
        ),
        onPressed: _showContactOptions,
      );
    }
  }

  Future<void> _showVerificationAttempts() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Attempts'),
        content: const SizedBox(
          width: double.maxFinite,
          child: Text('No verification attempts recorded.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _reportItem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Item'),
        content: const Text('Are you sure you want to report this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item reported successfully')),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCurrentUser = item.uploaderId == _currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.blue,
        actions: [
          if (!isCurrentUser && !_loading)
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: widget.item.requiresVerification
                  ? _showContactOptions
                  : _startChat,
              tooltip: 'Contact Uploader',
            ),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: item.imageUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      color: item.isLost ? Colors.red : Colors.green,
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Image Available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (item.requiresVerification && item.securityQuestions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.security,
                      color: Colors.purple,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'VERIFICATION REQUIRED',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (_isVerified && !isCurrentUser)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: item.isLost ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: item.isLost ? Colors.red.shade200 : Colors.green.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isLost ? Icons.search_off : Icons.search,
                    color: item.isLost ? Colors.red : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.isLost ? 'LOST ITEM' : 'FOUND ITEM',
                    style: TextStyle(
                      color: item.isLost ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              item.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _detailRow(
                    icon: Icons.person,
                    label: 'Reported by:',
                    value: isCurrentUser ? 'You' : item.uploader,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.location_on,
                    label: 'Location:',
                    value: item.location,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.category,
                    label: 'Category:',
                    value: item.category,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.date_range,
                    label: 'Date Lost/Found:',
                    value: DateFormat('MMM dd, yyyy').format(item.date),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.calendar_today,
                    label: 'Report Date:',
                    value: DateFormat('MMM dd, yyyy - hh:mm a').format(item.reportDate),
                  ),

                  if (item.requiresVerification)
                    _detailRow(
                      icon: Icons.security,
                      label: 'Security:',
                      value: '${item.securityQuestions.length} verification question(s)',
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                item.description.isNotEmpty ? item.description : 'No description provided.',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 30),

            _buildContactButton(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}