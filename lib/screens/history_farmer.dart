import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';

class FarmerHistoryScreen extends StatelessWidget {
  final String farmerId;

  const FarmerHistoryScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Milk History"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("milk_logs")
            .where("farmerId", isEqualTo: farmerId)
            .orderBy("date", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading history: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No milk records found."));
          }

          final logs = snapshot.data!.docs;

          // --- Calculate Totals ---
          double totalLiters = 0;
          double totalPaid = 0;
          double totalPending = 0;

          for (var log in logs) {
            final data = log.data() as Map<String, dynamic>;
            final liters = (data["quantity"] ?? 0).toDouble();
            totalLiters += liters;

            if (data["status"] == "paid") {
              totalPaid += liters * 50; // assume 50 KES per liter
            } else {
              totalPending += liters * 50;
            }
          }

          return Column(
            children: [
              // 🔹 Summary Section
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _summaryCard(
                      icon: Icons.local_drink,
                      title: "Total Milk Delivered",
                      value: "$totalLiters L",
                      color: Colors.blue,
                      bgColor: Colors.lightBlue.shade50,
                    ),
                    _summaryCard(
                      icon: Icons.check_circle,
                      title: "Total Paid",
                      value: "KES $totalPaid",
                      color: Colors.green,
                      bgColor: Colors.green.shade50,
                    ),
                    _summaryCard(
                      icon: Icons.pending_actions,
                      title: "Pending Payments",
                      value: "KES $totalPending",
                      color: Colors.orange,
                      bgColor: Colors.orange.shade50,
                    ),
                  ],
                ),
              ),

              const Divider(),

              // 🔹 Logs List
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final data = logs[index].data() as Map<String, dynamic>;
                    final date = (data["date"] as Timestamp).toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_drink,
                          color: Colors.green,
                        ),
                        title: Text("${data['quantity']} Liters"),
                        subtitle: Text(
                          "Date: ${DateFormat('MMM dd, yyyy – hh:mm a').format(date)}\n"
                          "Notes: ${data['notes'] ?? 'None'}",
                        ),
                        trailing: Chip(
                          label: Text(
                            data['status'] ?? "pending",
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: (data['status'] == "paid")
                              ? Colors.green
                              : Colors.red,
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // 🔽 Farmer Bottom Navigation
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // History Tab
        role: "farmer",
        farmerId: farmerId,
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      color: bgColor,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}
