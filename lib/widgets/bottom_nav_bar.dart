import 'package:flutter/material.dart';
import 'package:podago/screens/farmer/dashboard_farmer.dart';
import 'package:podago/screens/collector/dashboard_collector.dart';
import 'package:podago/screens/farmer/history_farmer.dart';
import 'package:podago/screens/collector/history_collector.dart';
import 'package:podago/screens/farmer/tips_farmer.dart';
import 'package:podago/screens/collector/tips_collector.dart';
import 'package:podago/screens/farmer/support_farmer.dart';
import 'package:podago/screens/collector/support_collector.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String role; // "farmer" or "collector"
  final String? farmerId; // Only needed if role == farmer

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.role,
    this.farmerId,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Already on this page

    Widget destination;

    if (role == "farmer") {
      switch (index) {
        case 0:
          destination = FarmerDashboard(farmerId: farmerId!);
          break;
        case 1:
          destination = FarmerHistoryScreen(farmerId: farmerId!);
          break;
        case 2:
          destination = FarmerTipsScreen(farmerId: farmerId!);
          break;
        case 3:
          destination = FarmerSupportScreen(farmerId: farmerId!);
          break;
        default:
          return;
      }
    } else {
      switch (index) {
        case 0:
          destination = const CollectorDashboard();
          break;
        case 1:
          destination = const CollectorHistoryScreen();
          break;
        case 2:
          destination = const CollectorTipsScreen();
          break;
        case 3:
          destination = const CollectorSupportScreen();
          break;
        default:
          return;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: "Tips"),
        BottomNavigationBarItem(
          icon: Icon(Icons.help_outline),
          label: "Support",
        ),
      ],
    );
  }
}
