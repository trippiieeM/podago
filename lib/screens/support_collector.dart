import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class CollectorSupportScreen extends StatelessWidget {
  const CollectorSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Support"),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text("☎️ Support for collectors: 0712 345 678"),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 3,
        role: "collector",
      ),
    );
  }
}
