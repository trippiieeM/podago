import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';

class FarmerSupportScreen extends StatelessWidget {
  final String farmerId;

  const FarmerSupportScreen({super.key, required this.farmerId});

  // --- Professional Theme Colors ---
  static const Color kPrimaryGreen = Color(0xFF1B5E20); // Deep Emerald
  static const Color kBackground = Color(0xFFF3F5F7);   // Light Grey-Blue
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF757575);

  // ===========================================================================
  // 1. LOGIC SECTION (STRICTLY PRESERVED)
  // ===========================================================================

  Future<void> _launchUrl(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open $url'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  // WhatsApp
  Future<void> _launchWhatsApp(BuildContext context) async {
    const phone = "254792746672";
    const message = "Hello, I need support with my Podago account";
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    await _launchUrl(url, context);
  }

  // Phone Call
  Future<void> _launchPhoneCall(BuildContext context) async {
    const phone = "+254792746672";
    final url = "tel:$phone";
    await _launchUrl(url, context);
  }

  // SMS
  Future<void> _launchSMS(BuildContext context) async {
    const phone = "+254792746672";
    const message = "Hello, I need support with my Podago account";
    final url = "sms:$phone?body=${Uri.encodeComponent(message)}";
    await _launchUrl(url, context);
  }

  // Email
  Future<void> _launchEmail(BuildContext context) async {
    const email = "muchirimorris007@gmail.com";
    const subject = "Support Request - Podago Farmer";
    const body = "Hello Podago Support Team,\n\nI need assistance with:\n\n";
    final url = "mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}";
    await _launchUrl(url, context);
  }

  // ===========================================================================
  // 2. UI SECTION (PROFESSIONAL REDESIGN)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Card ---
            _buildHeroCard(),
            const SizedBox(height: 24),

            // --- Contact Grid (Replaces vertical list) ---
            const Text("Contact Us", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildContactTile(
                  icon: Icons.headset_mic,
                  title: "Call Support",
                  subtitle: "Talk to us",
                  color: Colors.blue,
                  onTap: () => _launchPhoneCall(context),
                ),
                _buildContactTile(
                  icon: Icons.chat_bubble,
                  title: "WhatsApp",
                  subtitle: "Chat now",
                  color: Colors.green,
                  onTap: () => _launchWhatsApp(context),
                ),
                _buildContactTile(
                  icon: Icons.email,
                  title: "Email",
                  subtitle: "Send details",
                  color: Colors.purple,
                  onTap: () => _launchEmail(context),
                ),
                _buildContactTile(
                  icon: Icons.sms,
                  title: "SMS",
                  subtitle: "Text us",
                  color: Colors.orange,
                  onTap: () => _launchSMS(context),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- FAQ Section ---
            const Text("Frequently Asked Questions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
            const SizedBox(height: 12),
            _buildFAQList(),

            const SizedBox(height: 24),

            // --- Footer Info ---
            Center(
              child: Column(
                children: [
                  Icon(Icons.verified_user_outlined, color: Colors.grey.shade400, size: 40),
                  const SizedBox(height: 8),
                  Text("Support ID: $farmerId", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text("v1.0.0 • Podago Secure", style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 20),
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

  // --- UI Components ---

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryGreen, kPrimaryGreen.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: kPrimaryGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text("How can we help?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Our team is available 24/7 to assist with payments, collections, and app issues.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQList() {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Column(
        children: [
          _buildFAQTile(
            "How do I update my profile?",
            "Navigate to your profile section and tap on 'Edit Profile' to update your personal details securely.",
            showDivider: true,
          ),
          _buildFAQTile(
            "When are payments processed?",
            "Payments are automatically processed every Friday for the previous week's milk collection totals.",
            showDivider: true,
          ),
          _buildFAQTile(
            "Incorrect milk records?",
            "If you spot a discrepancy, please use the WhatsApp button above to send us a screenshot of your receipt.",
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer, {bool showDivider = true}) {
    return Column(
      children: [
        Theme(
          data: ThemeData().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextPrimary)),
            childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            children: [
              Text(answer, style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5)),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20),
      ],
    );
  }
}