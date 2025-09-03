import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class FarmerTipsScreen extends StatelessWidget {
  final String farmerId; // ✅ accept real farmerId

  const FarmerTipsScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context) {
    final tips = [
      "🐄 Feed your cows a balanced diet with enough protein, minerals, and clean water daily.",
      "🍼 Milk cows at the same time every day to maintain consistency and increase production.",
      "💧 Always clean udders before and after milking to prevent mastitis.",
      "🌱 Grow your own fodder crops (e.g., Napier grass, lucerne) to reduce feeding costs.",
      "🏠 Keep animal housing clean, dry, and well-ventilated to avoid diseases.",
      "💉 Vaccinate regularly and follow deworming schedules for healthier animals.",
      "📊 Keep proper records of milk production, breeding, and health for better planning.",
      "☀️ Provide enough shade and clean resting areas for cows to reduce stress.",
      "🧼 Always wash milking equipment thoroughly with hot water and detergent after every use.",
      "🤝 Join a cooperative to access training, veterinary services, and better milk prices.",
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Farming Tips"),
        backgroundColor: Colors.green,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.lightbulb, color: Colors.green),
              title: Text(tips[index], style: const TextStyle(fontSize: 16)),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        role: "farmer",
        farmerId: farmerId, // ✅ use real farmerId
      ),
    );
  }
}
