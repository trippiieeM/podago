import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_bar.dart';

class FarmerDashboard extends StatelessWidget {
  final String farmerId;

  const FarmerDashboard({super.key, required this.farmerId});

  Future<String> _getFarmerName() async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(farmerId)
        .get();
    return doc.data()?["name"] ?? "Farmer";
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text("PODAGO FARMER"),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<String>(
        future: _getFarmerName(),
        builder: (context, snapshot) {
          final farmerName = snapshot.data ?? "Farmer";

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👤 Header
                Text(
                  "Welcome, $farmerName",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat("EEEE, dd MMM yyyy").format(today),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // 🧮 Summary cards
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("milk_logs")
                      .where("farmerId", isEqualTo: farmerId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    final logs = snapshot.data?.docs ?? [];
                    double todayTotal = 0;
                    double monthTotal = 0;
                    double pendingTotal = 0;
                    const double pricePerLiter = 45;

                    for (var doc in logs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data["date"] as Timestamp).toDate();
                      final qty = (data["quantity"] ?? 0).toDouble();
                      final status = data["status"] ?? "pending";

                      if (DateFormat("yyyy-MM-dd").format(date) ==
                          DateFormat("yyyy-MM-dd").format(today)) {
                        todayTotal += qty;
                      }
                      if (date.month == today.month &&
                          date.year == today.year) {
                        monthTotal += qty;
                      }
                      if (status == "pending") {
                        pendingTotal += qty * pricePerLiter;
                      }
                    }

                    return Row(
                      children: [
                        Expanded(child: _summaryCard("Today", "$todayTotal L")),
                        Expanded(
                          child: _summaryCard("This Month", "$monthTotal L"),
                        ),
                        Expanded(
                          child: _summaryCard(
                            "Pending Pay",
                            "KES ${pendingTotal.toStringAsFixed(0)}",
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 📊 Chart
                const Text(
                  "Milk Trends (Last 7 Days)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(height: 200, child: _buildChart(farmerId)),

                const SizedBox(height: 20),
                const Text(
                  "Milk Logs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // 📋 Logs
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
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
                            "Error: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final logs = snapshot.data?.docs ?? [];
                      if (logs.isEmpty) {
                        return const Center(
                          child: Text("No milk records yet."),
                        );
                      }

                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log =
                              logs[index].data() as Map<String, dynamic>;
                          final date = (log["date"] as Timestamp).toDate();
                          final status = log["status"] ?? "pending";

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.local_drink,
                                color: status == "pending"
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              title: Text("${log["quantity"]} Liters"),
                              subtitle: Text(
                                "Notes: ${log["notes"] ?? "None"}\nStatus: $status",
                              ),
                              trailing: Text(
                                DateFormat("dd MMM, hh:mm a").format(date),
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
          );
        },
      ),

      // 🔽 Farmer Bottom Nav
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        role: "farmer",
        farmerId: farmerId,
      ),
    );
  }

  // 📦 Summary card widget
  Widget _summaryCard(String label, String value, {double fontSize = 16}) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 📊 Chart widget
  Widget _buildChart(String farmerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("milk_logs")
          .where("farmerId", isEqualTo: farmerId)
          .orderBy("date", descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final logs = snapshot.data?.docs ?? [];

        final now = DateTime.now();
        final last7Days = List.generate(7, (i) {
          final day = now.subtract(Duration(days: 6 - i));
          return DateFormat("yyyy-MM-dd").format(day);
        });

        Map<String, double> dailyTotals = {for (var d in last7Days) d: 0.0};

        for (var doc in logs) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data["date"] as Timestamp).toDate();
          final key = DateFormat("yyyy-MM-dd").format(date);
          final qty = (data["quantity"] ?? 0).toDouble();
          if (dailyTotals.containsKey(key)) {
            dailyTotals[key] = dailyTotals[key]! + qty;
          }
        }

        final spots = <FlSpot>[];
        for (var i = 0; i < last7Days.length; i++) {
          spots.add(FlSpot(i.toDouble(), dailyTotals[last7Days[i]]!));
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() < 0 ||
                        value.toInt() >= last7Days.length) {
                      return const SizedBox();
                    }
                    final date = last7Days[value.toInt()];
                    return Text(
                      DateFormat("E").format(DateTime.parse(date)),
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                spots: spots,
                color: Colors.green,
                barWidth: 3,
                dotData: FlDotData(show: true),
              ),
            ],
          ),
        );
      },
    );
  }
}
