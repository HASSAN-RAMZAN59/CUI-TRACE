import 'package:flutter/material.dart';
import 'chat_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _submitting = false;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I report a lost or found item?',
      'answer': 'Tap the big "+ Add Report" button at the bottom of the Home screen. Select whether it is a Lost or Found item, enter the title, location, category, upload a photo, and tap Submit!'
    },
    {
      'question': 'How does security question verification work?',
      'answer': 'When you post a Found item, you can add 1 or 2 security questions (e.g., "What color is the pouch?"). When someone claims the item, they must answer the security questions correctly before contacting you.'
    },
    {
      'question': 'How do I contact someone who posted a report?',
      'answer': 'Tap on any Lost or Found item report on the Home Screen. On the detail page, tap "Message Uploader" to open an instant 1-on-1 chat with the user.'
    },
    {
      'question': 'Where is the physical Lost & Found Help Desk located?',
      'answer': 'The official CUI Trace Physical Help Desk is located at the Student Support Center (SSC), Block A, COMSATS University Sahiwal Campus.'
    },
    {
      'question': 'What if my item is claimed by someone else wrongly?',
      'answer': 'You can report an item or user by tapping "Report Item" inside the item detail screen. Our campus security team will review the claim.'
    },
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback or inquiry message')),
      );
      return;
    }

    setState(() => _submitting = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _submitting = false;
          _feedbackController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Feedback submitted successfully! Our campus team will review it.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.headset_mic, size: 50, color: Colors.white),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUI Support Desk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We are here to help you find lost items on campus!',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Chat Support Tile
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.chat, color: Colors.white),
                ),
                title: const Text('Live Campus Support Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Connect directly with COMSATS Lost & Found desk'),
                trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen(
                        chatId: 'chat_campus_support',
                        otherUserId: 'user_support',
                        otherUserName: 'COMSATS Campus HelpDesk',
                        itemTitle: 'Campus Lost & Found Inquiry',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // FAQs Section Header
            const Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),

            // FAQs Accordion List
            ..._faqs.map((faq) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.help_outline, color: Colors.blue),
                title: Text(
                  faq['question']!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Text(
                      faq['answer']!,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),

            // Send Feedback Section
            const Text(
              'SUBMIT FEEDBACK OR REPORT AN ISSUE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _feedbackController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Describe your issue or suggestion...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submitFeedback,
                        icon: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(_submitting ? 'Submitting...' : 'Submit Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Info Footer
            Card(
              elevation: 1,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.email, color: Colors.blue, size: 20),
                        SizedBox(width: 10),
                        Text('Email: support@cui-trace.edu.pk', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.phone, color: Colors.green, size: 20),
                        SizedBox(width: 10),
                        Text('Campus Helpline: +92 (040) 4305001', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
