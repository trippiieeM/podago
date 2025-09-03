import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';

class CollectorHistoryScreen extends StatefulWidget {
  const CollectorHistoryScreen({super.key});

  @override
  State<CollectorHistoryScreen> createState() => _CollectorHistoryScreenState();
}

class _CollectorHistoryScreenState extends State<CollectorHistoryScreen> {
  String? selectedFarmerId;
  DateTime? selectedDate;

  /// Pick a date filter
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    Query logsQuery = FirebaseFirestore.instance
        .collection("milk_logs")
        .orderBy("date", descending: true);

    if (selectedFarmerId != null) {
      logsQuery = logsQuery.where("farmerId", isEqualTo: selectedFarmerId);
    }
    if (selectedDate != null) {
      final start = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
      final end = start.add(const Duration(days: 1));
      logsQuery = logsQuery.where(
        "date",
        isGreaterThanOrEqualTo: start,
        isLessThan: end,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Collector History"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // ---------- FILTERS ----------
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 🧑 Farmer filter (pull list from users collection)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
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
                        hint: const Text("Filter by Farmer"),
                        items: farmers.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['name'] ?? 'Unnamed Farmer'),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => selectedFarmerId = value),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    selectedDate == null
                        ? "Pick Date"
                        : DateFormat("MMM dd").format(selectedDate!),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // ---------- LOGS LIST ----------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: logsQuery.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data!.docs;
                if (logs.isEmpty) {
                  return const Center(child: Text("No milk logs found."));
                }

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    final farmerName = log['farmerName'] ?? "Unnamed Farmer";

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_drink,
                          color: Colors.green,
                        ),
                        title: Text("${log['quantity']} Liters"),
                        subtitle: Text(
                          "Farmer: $farmerName\nNotes: ${log['notes'] ?? 'None'}",
                        ),
                        trailing: Text(
                          DateFormat(
                            'MMM dd, hh:mm a',
                          ).format((log['date'] as Timestamp).toDate()),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 🔽 Bottom Nav
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
        role: "collector",
      ),
    );
  }
}
