import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LogMilkScreen extends StatefulWidget {
  const LogMilkScreen({super.key});

  @override
  State<LogMilkScreen> createState() => _LogMilkScreenState();
}

class _LogMilkScreenState extends State<LogMilkScreen> {
  String? selectedFarmerId;
  String? selectedFarmerName;
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  Future<void> _saveLog() async {
    if (selectedFarmerId == null || selectedFarmerName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a farmer")));
      return;
    }

    final quantity = double.tryParse(quantityCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    await FirebaseFirestore.instance.collection("milk_logs").add({
      "farmerId": selectedFarmerId,
      "farmerName": selectedFarmerName,
      "quantity": quantity,
      "notes": notes,
      "date": now,
      "dateStr": dateStr,
      "status": "pending",
    });

    Navigator.pop(context); // back to dashboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Milk"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔽 Dropdown to select farmer
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .where("role", isEqualTo: "farmer")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final farmers = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Select Farmer",
                    border: OutlineInputBorder(),
                  ),
                  value: selectedFarmerId,
                  items: farmers.map((farmer) {
                    final data = farmer.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: farmer.id,
                      child: Text(data["name"] ?? "Unnamed Farmer"),
                      onTap: () {
                        selectedFarmerName = data["name"];
                      },
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedFarmerId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Quantity input
            TextField(
              controller: quantityCtrl,
              decoration: const InputDecoration(
                labelText: "Quantity (Liters)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Notes input
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: "Notes",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: _saveLog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Save Log"),
            ),
          ],
        ),
      ),
    );
  }
}
