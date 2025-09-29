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
  String _searchQuery = '';

  /// Pick a date filter
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
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
        title: const Text(
          "Collection History",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[400],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Filters Section
          _buildFiltersSection(),
          
          // Statistics Section
          _buildStatisticsSection(logsQuery),
          
          // Logs List
          Expanded(
            child: _buildLogsList(logsQuery),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
        role: "collector",
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: Colors.green[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Collection History",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                    ),
                    Text(
                      "View and filter past milk collections",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: "Search by farmer name or notes...",
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              // Farmer Filter
              Expanded(
                flex: 2,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .where("role", isEqualTo: "farmer")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final farmers = snapshot.data?.docs ?? [];

                    return DropdownButtonFormField<String>(
                      value: selectedFarmerId,
                      hint: const Text("All Farmers"),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("All Farmers"),
                        ),
                        ...farmers.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['name'] ?? 'Unnamed Farmer'),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) => setState(() => selectedFarmerId = value),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Date Filter
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    color: selectedDate == null ? Colors.grey : Colors.green[700],
                  ),
                  label: Text(
                    selectedDate == null
                        ? "All Dates"
                        : DateFormat("MMM dd").format(selectedDate!),
                    style: TextStyle(
                      color: selectedDate == null ? Colors.grey : Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[50],
                    foregroundColor: Colors.green[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          // Clear Filters Button
          if (selectedFarmerId != null || selectedDate != null || _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text("Clear Filters"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(Query logsQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: logsQuery.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        
        final logs = snapshot.data!.docs;
        if (logs.isEmpty) return const SizedBox();
        
        final totalLiters = _calculateTotalLiters(logs);
        final uniqueFarmers = <String>{};
        
        for (final log in logs) {
          final data = log.data() as Map<String, dynamic>;
          uniqueFarmers.add(data['farmerName'] ?? 'Unknown');
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.water_drop_rounded,
                "${totalLiters.toStringAsFixed(1)}L",
                "Total Milk",
                Colors.blue[700]!,
              ),
              _buildStatItem(
                Icons.list_alt_rounded,
                logs.length.toString(),
                "Collections",
                Colors.green[700]!,
              ),
              _buildStatItem(
                Icons.people_rounded,
                uniqueFarmers.length.toString(),
                "Farmers",
                Colors.orange[700]!,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLogsList(Query logsQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: logsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  "Loading collection history...",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        List<QueryDocumentSnapshot> logs = snapshot.data!.docs;
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          logs = logs.where((log) {
            final data = log.data() as Map<String, dynamic>;
            final farmerName = (data['farmerName'] ?? '').toString().toLowerCase();
            final notes = (data['notes'] ?? '').toString().toLowerCase();
            return farmerName.contains(_searchQuery) || notes.contains(_searchQuery);
          }).toList();
        }

        if (logs.isEmpty) {
          return _buildEmptySearchState();
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Collection Records (${logs.length})",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    return _buildLogCard(log, index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final timestamp = (log['date'] as Timestamp).toDate();
    final farmerName = log['farmerName'] ?? "Unknown Farmer";
    final quantity = log['quantity'] ?? 0.0;
    final notes = log['notes'] ?? '';

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Quantity Indicator
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    quantity.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'L',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Log Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Collected',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Collection History",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "Milk collection records will appear here\nonce you start logging collections.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "No matching records",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}