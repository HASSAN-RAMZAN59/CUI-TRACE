import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Shield Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip, size: 40, color: Colors.blue),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Protection & Privacy Policy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'CUI Trace - COMSATS University Sahiwal',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(
              title: '1. Information We Collect',
              icon: Icons.person_outline,
              content:
                  'We collect information necessary to operate the campus lost and found service, including your name, official campus email address, phone number, and report details (item title, location, category, and uploaded item images).',
            ),
            _buildSection(
              title: '2. How Your Information Is Used',
              icon: Icons.security,
              content:
                  'Your information is strictly used to match lost items with their rightful owners within COMSATS University Sahiwal Campus. Your email and phone number are kept private unless explicitly shared by you in direct chat conversations.',
            ),
            _buildSection(
              title: '3. Item Verification & Claim Security',
              icon: Icons.verified_user_outlined,
              content:
                  'To prevent false claims of high-value items (such as laptops, mobiles, and student IDs), users may be required to answer specific security questions set by the finder before contacting the uploader.',
            ),
            _buildSection(
              title: '4. Data Storage & Security',
              icon: Icons.lock_outline,
              content:
                  'All data transmitted through CUI Trace is encrypted using SSL/TLS protocols and stored securely in local device storage and database servers. Users can clear local cached data at any time from Settings.',
            ),
            _buildSection(
              title: '5. Data Rights & Account Control',
              icon: Icons.manage_accounts_outlined,
              content:
                  'You have full control over your user profile and posted reports. You can edit or delete your report items at any time from the My Reports tab or home screen.',
            ),
            _buildSection(
              title: '6. Policy Updates & Contact',
              icon: Icons.info_outline,
              content:
                  'This policy may be updated periodically to reflect improvements in campus security. If you have questions regarding privacy, email our Data Protection Officer at privacy@cui-trace.edu.pk.',
            ),
            const SizedBox(height: 20),

            Center(
              child: Text(
                'Last Updated: July 2026\nCOMSATS University Sahiwal Campus',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
