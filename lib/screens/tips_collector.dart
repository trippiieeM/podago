import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class CollectorTipsScreen extends StatelessWidget {
  const CollectorTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Collector Tips"),
        backgroundColor: Colors.green,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text("🚚 Best practices for collection and record-keeping."),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 2,
        role: "collector",
      ),
    );
  }
}
