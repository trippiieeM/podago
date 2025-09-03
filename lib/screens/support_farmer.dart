import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Add this in pubspec.yaml under dependencies
import '../widgets/bottom_nav_bar.dart';

class FarmerSupportScreen extends StatelessWidget {
  final String farmerId; // ✅ accept real farmerId

  const FarmerSupportScreen({super.key, required this.farmerId});

  // 🔗 Helper function to launch URLs
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Support"),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Need help? Contact us through any of the following options:",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),

          // 📞 Call Support
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text("Call Support"),
              subtitle: const Text("0700 123 456"),
              onTap: () => _launchUrl("tel:0700123456"),
            ),
          ),

          // 💬 WhatsApp Support
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text("WhatsApp Support"),
              subtitle: const Text("Chat with us on WhatsApp"),
              onTap: () => _launchUrl("https://wa.me/254700123456"),
            ),
          ),

          // 📧 Email Support
          Card(
            child: ListTile(
              leading: const Icon(Icons.email, color: Colors.green),
              title: const Text("Email Support"),
              subtitle: const Text("support@podago.com"),
              onTap: () => _launchUrl("mailto:support@podago.com"),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        role: "farmer",
        farmerId: farmerId, // ✅ use real farmerId
      ),
    );
  }
}
