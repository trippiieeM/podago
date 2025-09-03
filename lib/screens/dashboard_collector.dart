import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';
import 'register_farmer_screen.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  String? selectedFarmerId;
  String? selectedFarmerName; // ✅ store farmer name too
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  Future<void> _logMilk() async {
    if (selectedFarmerId == null || quantityCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select farmer and enter quantity"),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("milk_logs").add({
      "farmerId": selectedFarmerId,
      "farmerName": selectedFarmerName, // ✅ save name here
      "quantity": double.tryParse(quantityCtrl.text) ?? 0,
      "notes": notesCtrl.text,
      "status": "pending",
      "date": DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Milk log saved successfully")),
    );

    quantityCtrl.clear();
    notesCtrl.clear();
    setState(() {
      selectedFarmerId = null;
      selectedFarmerName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Collector Dashboard"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Register Farmer",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterFarmerScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- MILK INPUT FORM ----------
            const Text("Select Farmer", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
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
                  value: selectedFarmerId,
                  hint: const Text("Choose farmer"),
                  items: farmers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unnamed Farmer';
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(name),
                      onTap: () {
                        selectedFarmerName = name; // ✅ capture farmer name
                      },
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedFarmerId = value;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityCtrl,
              decoration: const InputDecoration(
                labelText: "Quantity (Liters)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: "Notes",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _logMilk,
              icon: const Icon(Icons.save),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              label: const Text("Save Milk Log"),
            ),

            const SizedBox(height: 30),
            const Text(
              "Today’s Collected Milk",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // ---------- TODAY’S LOGS LIST ----------
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("milk_logs")
                    .where(
                      "date",
                      isGreaterThanOrEqualTo: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ),
                    )
                    .orderBy("date", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final logs = snapshot.data!.docs;
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text("No milk collected today yet."),
                    );
                  }

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_drink,
                            color: Colors.green,
                          ),
                          title: Text("${log['quantity']} Liters"),
                          subtitle: Text(
                            "Farmer: ${log['farmerName'] ?? 'Unknown'}\n"
                            "Notes: ${log['notes'] ?? 'None'}",
                          ),
                          trailing: Text(
                            DateFormat(
                              'hh:mm a',
                            ).format((log['date'] as Timestamp).toDate()),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // 🔽 Bottom Navigation
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 0,
        role: "collector",
      ),
    );
  }
}
