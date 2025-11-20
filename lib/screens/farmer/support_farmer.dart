import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';

class FarmerSupportScreen extends StatelessWidget {
  final String farmerId;

  const FarmerSupportScreen({super.key, required this.farmerId});

  Future<void> _launchUrl(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Show error message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open $url'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // WhatsApp launch with proper formatting
  Future<void> _launchWhatsApp(BuildContext context) async {
    const phone = "254792746672"; // Kenyan number without +
    const message = "Hello, I need support with my Podago account";
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    await _launchUrl(url, context);
  }

  // Phone call launch
  Future<void> _launchPhoneCall(BuildContext context) async {
    const phone = "+254792746672"; // International format with +
    final url = "tel:$phone";
    await _launchUrl(url, context);
  }

  // SMS launch
  Future<void> _launchSMS(BuildContext context) async {
    const phone = "+254792746672"; // International format with +
    const message = "Hello, I need support with my Podago account";
    final url = "sms:$phone?body=${Uri.encodeComponent(message)}";
    await _launchUrl(url, context);
  }

  // Email launch
  Future<void> _launchEmail(BuildContext context) async {
    const email = "muchirimorris007@gmail.com";
    const subject = "Support Request - Podago Farmer";
    const body = "Hello Podago Support Team,\n\nI need assistance with:\n\n";
    final url = "mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}";
    await _launchUrl(url, context);
  }

  Widget _buildSupportCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "We're Here to Help!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Get instant support for any issues with milk collection, payments, or technical problems. Our team is available 24/7 to assist you.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                "Available 24/7",
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.verified_user,
                size: 14,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                "Quick Response",
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.chat_bubble_outline,
                label: "Live Chat",
                color: Colors.green,
                onTap: () => _launchWhatsApp(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.phone_in_talk,
                label: "Call Now",
                color: Colors.blue,
                onTap: () => _launchPhoneCall(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Frequently Asked Questions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildFAQItem(
          question: "How do I update my profile information?",
          answer: "Go to your profile section and tap on 'Edit Profile' to update your details.",
        ),
        _buildFAQItem(
          question: "When will I receive my payments?",
          answer: "Payments are processed every Friday for the previous week's milk collection.",
        ),
        _buildFAQItem(
          question: "What if my milk quantity is recorded incorrectly?",
          answer: "Contact support immediately with your collection details for correction.",
        ),
      ],
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Support Center",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            _buildInfoCard(),

            // Quick Actions
            _buildQuickActions(context),
            const SizedBox(height: 24),

            // Support Channels
            const Text(
              "Support Channels",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Phone Support
            _buildSupportCard(
              icon: Icons.phone,
              color: Colors.green,
              title: "Call Support",
              subtitle: "+254 792 746 672",
              description: "Speak directly with our support team",
              onTap: () => _launchPhoneCall(context),
            ),

            // WhatsApp Support
            _buildSupportCard(
              icon: Icons.chat,
              color: Colors.green,
              title: "WhatsApp Support",
              subtitle: "+254 792 746 672",
              description: "Get instant messaging support",
              onTap: () => _launchWhatsApp(context),
            ),

            // Email Support
            _buildSupportCard(
              icon: Icons.email,
              color: Colors.blue,
              title: "Email Support",
              subtitle: "muchirimorris007@gmail.com",
              description: "Send us detailed queries",
              onTap: () => _launchEmail(context),
            ),

            // SMS Support
            _buildSupportCard(
              icon: Icons.sms,
              color: Colors.orange,
              title: "SMS Support",
              subtitle: "+254 792 746 672",
              description: "Text us for quick assistance",
              onTap: () => _launchSMS(context),
            ),

            const SizedBox(height: 24),

            // FAQ Section
            _buildFAQSection(),

            const SizedBox(height: 20),

            // Footer Note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 32,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your satisfaction is our priority",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Average response time: 15 minutes",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        role: "farmer",
        farmerId: farmerId,
      ),
    );
  }
}