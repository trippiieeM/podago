import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';

class CollectorHistoryScreen extends StatefulWidget {
  const CollectorHistoryScreen({super.key});

  @override
  State<CollectorHistoryScreen> createState() => _CollectorHistoryScreenState();
}

class _CollectorHistoryScreenState extends State<CollectorHistoryScreen> {
  // --- Professional Theme Colors ---
  static const Color kPrimaryColor = Color(0xFF00695C); // Teal 800
  static const Color kBackgroundColor = Color(0xFFF5F7FA);
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF263238);
  static const Color kTextSecondary = Color(0xFF78909C);

  String? selectedFarmerId;
  DateTime? selectedDate;
  String _searchQuery = '';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _clearFilters() {
    setState(() {
      selectedFarmerId = null;
      selectedDate = null;
      _searchQuery = '';
    });
  }

  double _calculateTotalLiters(List<QueryDocumentSnapshot> logs) {
    return logs.fold(0.0, (total, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return total + (data['quantity'] ?? 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    Query logsQuery = FirebaseFirestore.instance.collection("milk_logs").orderBy("date", descending: true);

    if (selectedFarmerId != null) {
      logsQuery = logsQuery.where("farmerId", isEqualTo: selectedFarmerId);
    }
    if (selectedDate != null) {
      final start = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      final end = start.add(const Duration(days: 1));
      logsQuery = logsQuery.where("date", isGreaterThanOrEqualTo: start, isLessThan: end);
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("Collection History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (selectedFarmerId != null || selectedDate != null || _searchQuery.isNotEmpty)
            TextButton(
              onPressed: _clearFilters,
              child: const Text("Clear Filters", style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: Column(
        children: [
          // 1. Statistics Panel
          _buildStatisticsSection(logsQuery),

          // 2. Search & Filters
          _buildFiltersSection(),

          // 3. List Data
          Expanded(
            child: _buildLogsList(logsQuery),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1, role: "collector"),
    );
  }

  Widget _buildStatisticsSection(Query logsQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: logsQuery.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final logs = snapshot.data!.docs;
        // Even if empty, show zero stats
        final totalLiters = logs.isEmpty ? 0.0 : _calculateTotalLiters(logs);
        final uniqueFarmers = <String>{};
        if (logs.isNotEmpty) {
          for (final log in logs) {
            final data = log.data() as Map<String, dynamic>;
            uniqueFarmers.add(data['farmerName'] ?? 'Unknown');
          }
        }

        return Container(
          color: kPrimaryColor,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(Icons.water_drop, "${totalLiters.toStringAsFixed(1)}L", "Total Volume"),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                _buildStatItem(Icons.receipt_long, "${logs.length}", "Records"),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                _buildStatItem(Icons.people, "${uniqueFarmers.length}", "Farmers"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 12, color: kTextSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: kBackgroundColor,
      child: Column(
        children: [
          // Search Bar
          TextField(
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search farmer or notes...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search, color: kTextSecondary),
              filled: true,
              fillColor: kCardColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              // Farmer Dropdown
              Expanded(
                flex: 3,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("users").where("role", isEqualTo: "farmer").snapshots(),
                  builder: (context, snapshot) {
                    final farmers = snapshot.data?.docs ?? [];
                    return Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: kCardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFarmerId,
                          isExpanded: true,
                          hint: const Text("All Farmers", style: TextStyle(fontSize: 13, color: kTextSecondary)),
                          icon: const Icon(Icons.arrow_drop_down, color: kTextSecondary),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text("All Farmers", style: TextStyle(fontSize: 13))),
                            ...farmers.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) => setState(() => selectedFarmerId = value),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Date Picker Button
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _pickDate,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedDate != null ? kPrimaryColor : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: selectedDate != null ? kPrimaryColor : kTextSecondary),
                        const SizedBox(width: 8),
                        Text(
                          selectedDate == null ? "Date" : DateFormat("MMM dd").format(selectedDate!),
                          style: TextStyle(
                            fontSize: 13,
                            color: selectedDate != null ? kPrimaryColor : kTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(Query logsQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: logsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

        List<QueryDocumentSnapshot> logs = snapshot.data!.docs;
        
        // Client-side search filter
        if (_searchQuery.isNotEmpty) {
          logs = logs.where((log) {
            final data = log.data() as Map<String, dynamic>;
            final farmerName = (data['farmerName'] ?? '').toString().toLowerCase();
            final notes = (data['notes'] ?? '').toString().toLowerCase();
            return farmerName.contains(_searchQuery) || notes.contains(_searchQuery);
          }).toList();
        }

        if (logs.isEmpty) return _buildEmptySearchState();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            return _buildLogCard(log);
          },
        );
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final timestamp = (log['date'] as Timestamp).toDate();
    final farmerName = log['farmerName'] ?? "Unknown";
    final quantity = (log['quantity'] ?? 0.0).toDouble();
    final notes = log['notes'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(DateFormat('MMM').format(timestamp).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextSecondary)),
                  Text(DateFormat('dd').format(timestamp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(farmerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(DateFormat('hh:mm a').format(timestamp), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(child: Text("• $notes", style: TextStyle(fontSize: 12, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            
            // Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${quantity.toStringAsFixed(1)}L",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No collection history found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No matching records", style: TextStyle(color: kTextSecondary)),
        ],
      ),
    );
  }
}