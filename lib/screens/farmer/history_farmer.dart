import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';

class FarmerHistoryScreen extends StatefulWidget {
  final String farmerId;

  const FarmerHistoryScreen({super.key, required this.farmerId});

  @override
  State<FarmerHistoryScreen> createState() => _FarmerHistoryScreenState();
}

class _FarmerHistoryScreenState extends State<FarmerHistoryScreen> {
  // --- Professional Theme Colors ---
  static const Color kPrimaryGreen = Color(0xFF1B5E20); // Deep Emerald
  static const Color kBackground = Color(0xFFF3F5F7);   // Light Grey-Blue
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF757575);

  // --- Logic Variables (Preserved) ---
  double _pricePerLiter = 45.0; 
  String _timeFilter = 'all'; 
  bool _isLoadingPrice = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentMilkPrice();
  }
  /// --- Fetch current milk price from admin system ---
  Future<void> _fetchCurrentMilkPrice() async {
    try {
      // Method 1: System Config
      final priceConfig = await FirebaseFirestore.instance.collection('system_config').doc('milk_price').get();
      if (priceConfig.exists) {
        final data = priceConfig.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('pricePerLiter')) {
          setState(() { _pricePerLiter = (data['pricePerLiter'] ?? 45.0).toDouble(); _isLoadingPrice = false; });
          return;
        }
      }
      // Method 2: Recent Payments
      final recentPayments = await FirebaseFirestore.instance.collection('payments').where('type', isEqualTo: 'milk_payment').orderBy('createdAt', descending: true).limit(1).get();
      if (recentPayments.docs.isNotEmpty) {
        final paymentData = recentPayments.docs.first.data();
        if (paymentData.containsKey('pricePerLiter')) {
          setState(() { _pricePerLiter = (paymentData['pricePerLiter'] ?? 45.0).toDouble(); _isLoadingPrice = false; });
          return;
        }
      }
      // Method 3: Recent Logs
      final recentMilkLogs = await FirebaseFirestore.instance.collection('milk_logs').where('status', isEqualTo: 'paid').orderBy('date', descending: true).limit(1).get();
      if (recentMilkLogs.docs.isNotEmpty) {
        final milkData = recentMilkLogs.docs.first.data();
        if (milkData.containsKey('pricePerLiter')) {
          setState(() { _pricePerLiter = (milkData['pricePerLiter'] ?? 45.0).toDouble(); _isLoadingPrice = false; });
          return;
        }
      }
      // Fallback
      setState(() { _pricePerLiter = 45.0; _isLoadingPrice = false; });
    } catch (error) {
      setState(() { _pricePerLiter = 45.0; _isLoadingPrice = false; });
    }
  }

  /// --- Filter Helper ---
  List<DocumentSnapshot> _applyFilter(List<DocumentSnapshot> docs) {
    if (_timeFilter == 'all') return docs;
    final now = DateTime.now();
    late DateTime startDate;
    switch (_timeFilter) {
      case 'day': startDate = DateTime(now.year, now.month, now.day); break;
      case 'week': startDate = now.subtract(const Duration(days: 7)); break;
      case 'month': startDate = DateTime(now.year, now.month - 1, now.day); break;
      case 'year': startDate = DateTime(now.year - 1, now.month, now.day); break;
      default: startDate = DateTime(2000);
    }
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      return date.isAfter(startDate);
    }).toList();
  }

  /// --- Fetch Payment Data ---
  Future<Map<String, dynamic>> _fetchPaymentData() async {
    try {
      final paymentsQuery = FirebaseFirestore.instance.collection('payments').where('farmerId', isEqualTo: widget.farmerId).orderBy('createdAt', descending: true);
      final paymentsSnapshot = await paymentsQuery.get();
      
      final milkPayments = paymentsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['type'] == 'milk_payment';
      }).toList();

      final feedDeductions = paymentsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['type'] == 'feed_deduction' && data['status'] != 'processed';
      }).toList();

      final milkLogsQuery = FirebaseFirestore.instance.collection('milk_logs').where('farmerId', isEqualTo: widget.farmerId).orderBy('date', descending: true);
      final milkLogsSnapshot = await milkLogsQuery.get();

      return { 'milkPayments': milkPayments, 'feedDeductions': feedDeductions, 'milkLogs': milkLogsSnapshot.docs };
    } catch (error) {
      return { 'milkPayments': [], 'feedDeductions': [], 'milkLogs': [] };
    }
  }

  /// --- Calculate Totals ---
  Map<String, double> _calculatePaymentTotals(Map<String, dynamic> paymentData) {
    final milkPayments = paymentData['milkPayments'] as List<DocumentSnapshot>;
    final feedDeductions = paymentData['feedDeductions'] as List<DocumentSnapshot>;
    final milkLogs = paymentData['milkLogs'] as List<DocumentSnapshot>;

    final paidMilkLogs = milkLogs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'paid').toList();
    final pendingMilkLogs = milkLogs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'pending').toList();

    double totalMilkIncome = paidMilkLogs.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final price = (data['pricePerLiter'] ?? _pricePerLiter).toDouble();
      return sum + ((data['quantity'] ?? 0).toDouble() * price);
    });

    if (totalMilkIncome == 0 && milkPayments.isNotEmpty) {
      totalMilkIncome = milkPayments.fold(0.0, (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['amount'] ?? 0.0));
    }

    double totalPendingMilk = pendingMilkLogs.fold(0.0, (sum, doc) {
      return sum + (((doc.data() as Map<String, dynamic>)['quantity'] ?? 0).toDouble() * _pricePerLiter);
    });

    double totalFeedDeductions = feedDeductions.fold(0.0, (sum, doc) {
      final amount = (doc.data() as Map<String, dynamic>)['amount'] ?? 0.0;
      return sum + (amount < 0 ? amount.abs() : amount);
    });

    double deductionsAppliedToPending = 0.0;
    double remainingPendingAfterDeductions = 0.0;

    if (totalFeedDeductions > 0 && totalPendingMilk > 0) {
      if (totalFeedDeductions <= totalPendingMilk) {
        deductionsAppliedToPending = totalFeedDeductions;
        remainingPendingAfterDeductions = totalPendingMilk - totalFeedDeductions;
      } else {
        deductionsAppliedToPending = totalPendingMilk;
        remainingPendingAfterDeductions = 0.0;
      }
    } else {
      deductionsAppliedToPending = 0.0;
      remainingPendingAfterDeductions = totalPendingMilk;
    }

    return {
      'totalMilkIncome': totalMilkIncome,
      'totalPendingMilk': totalPendingMilk,
      'totalFeedDeductions': totalFeedDeductions,
      'remainingPendingAfterDeductions': remainingPendingAfterDeductions,
      'deductionsAppliedToPending': deductionsAppliedToPending,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text("Transactions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kTextSecondary),
            onPressed: () { setState(() { _isLoadingPrice = true; }); _fetchCurrentMilkPrice(); },
          ),
        ],
      ),
      body: _isLoadingPrice 
          ? _buildLoadingState()
          : FutureBuilder<Map<String, dynamic>>(
              future: _fetchPaymentData(),
              builder: (context, paymentSnapshot) {
                if (paymentSnapshot.connectionState == ConnectionState.waiting) return _buildLoadingState();
                if (paymentSnapshot.hasError) return _buildErrorState(paymentSnapshot.error.toString());

                final paymentData = paymentSnapshot.data ?? { 'milkPayments': [], 'feedDeductions': [], 'milkLogs': [] };
                final paymentTotals = _calculatePaymentTotals(paymentData);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("milk_logs").where("farmerId", isEqualTo: widget.farmerId).orderBy("date", descending: true).snapshots(),
                  builder: (context, milkSnapshot) {
                    if (milkSnapshot.connectionState == ConnectionState.waiting) return _buildLoadingState();
                    if (!milkSnapshot.hasData || milkSnapshot.data!.docs.isEmpty) return _buildEmptyState();

                    final filteredLogs = _applyFilter(milkSnapshot.data!.docs);
                    if (filteredLogs.isEmpty) return _buildEmptyState();

                    double totalLiters = filteredLogs.fold(0.0, (sum, log) {
                      return sum + ((log.data() as Map<String, dynamic>)["quantity"] ?? 0).toDouble();
                    });

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPriceHeader(),
                          const SizedBox(height: 16),
                          
                          // --- Financial Summary Grid ---
                          _buildSectionTitle("Financial Overview"),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildSummaryCard(
                                title: "Total Income", 
                                value: "KES ${NumberFormat.compact().format(paymentTotals['totalMilkIncome'])}",
                                subtitle: "Protected Earnings",
                                icon: Icons.verified_user_outlined, 
                                color: kPrimaryGreen
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSummaryCard(
                                title: "Deductions", 
                                value: "KES ${NumberFormat.compact().format(paymentTotals['totalFeedDeductions'])}", 
                                subtitle: "Feed & Inputs",
                                icon: Icons.shopping_bag_outlined, 
                                color: Colors.redAccent
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildNetPendingCard(paymentTotals),
                          
                          const SizedBox(height: 24),
                          
                          // --- Filters ---
                          _buildTimeFilter(),
                          const SizedBox(height: 16),
                          
                          // --- Detailed History ---
                          _buildSectionTitle("Transaction History"),
                          const SizedBox(height: 12),
                          
                          // Admin Payments & Deductions
                          if ((paymentData['milkPayments'] as List).isNotEmpty || (paymentData['feedDeductions'] as List).isNotEmpty)
                             ...paymentData['milkPayments'].map((doc) => _buildPaymentRecordCard(doc, 0, 'milk_payment')),
                             
                          if ((paymentData['feedDeductions'] as List).isNotEmpty)
                             ...paymentData['feedDeductions'].map((doc) => _buildPaymentRecordCard(doc, 0, 'feed_deduction')),

                          // Milk Logs
                          ...filteredLogs.asMap().entries.map((entry) => 
                            _buildMilkRecordCard(entry.value, entry.key)
                          ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, role: "farmer", farmerId: widget.farmerId),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildPriceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text("Current Rate: ", style: TextStyle(color: Colors.blue[800], fontSize: 13)),
              Text("KES $_pricePerLiter / L", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Text(DateFormat('MMM dd').format(DateTime.now()), style: TextStyle(color: Colors.blue[300], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: kTextSecondary)),
        ],
      ),
    );
  }

  // Specialized card for the complex logic regarding Pending vs Deducted
  Widget _buildNetPendingCard(Map<String, double> totals) {
    final netPending = totals['remainingPendingAfterDeductions'] ?? 0;
    final totalPending = totals['totalPendingMilk'] ?? 0;
    final deducted = totals['deductionsAppliedToPending'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.orange.shade100]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Net Pending Payout", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
              Icon(Icons.pending_actions, color: Colors.orange.shade800, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text("KES ${NumberFormat("#,###").format(netPending)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
          const SizedBox(height: 8),
          const Divider(color: Colors.orangeAccent),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Gross Pending: KES ${NumberFormat.compact().format(totalPending)}", style: const TextStyle(fontSize: 12, color: Colors.brown)),
              if(deducted > 0)
                Text("- KES ${NumberFormat.compact().format(deducted)} (Fees)", style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All Time', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Today', 'day'),
          const SizedBox(width: 8),
          _buildFilterChip('This Week', 'week'),
          const SizedBox(width: 8),
          _buildFilterChip('This Month', 'month'),
          const SizedBox(width: 8),
          _buildFilterChip('This Year', 'year'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPrimaryGreen : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: kPrimaryGreen.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // --- Record List Items ---

  Widget _buildPaymentRecordCard(DocumentSnapshot doc, int index, String type) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['createdAt'] ?? data['date'] as Timestamp).toDate();
    final amount = (data['amount'] ?? 0).toDouble();
    final isDeduction = type == 'feed_deduction' || amount < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: isDeduction ? Colors.red : Colors.green, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isDeduction ? 'Feed Deduction' : 'Milk Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(DateFormat('MMM dd • hh:mm a').format(date), style: const TextStyle(color: kTextSecondary, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Text(
            "${isDeduction ? '-' : '+'} KES ${amount.abs().toStringAsFixed(0)}",
            style: TextStyle(color: isDeduction ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildMilkRecordCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data["date"] as Timestamp).toDate();
    final quantity = (data['quantity'] ?? 0).toDouble();
    final status = data['status'] ?? 'pending';
    final price = (data['pricePerLiter'] ?? _pricePerLiter).toDouble();
    final amount = quantity * price;

    // Status Badge Logic
    Color statusColor;
    Color statusBg;
    if (status == 'paid') { statusColor = Colors.green; statusBg = Colors.green.shade50; }
    else if (status == 'deducted') { statusColor = Colors.orange; statusBg = Colors.orange.shade50; }
    else { statusColor = Colors.grey; statusBg = Colors.grey.shade100; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${quantity.toStringAsFixed(1)} Liters", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(color: kTextSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("KES ${amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
      ),
    );
  }

  // --- States ---
  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: kPrimaryGreen));
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text("Could not load data", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
          TextButton(onPressed: () { setState(() {_isLoadingPrice = true;}); _fetchCurrentMilkPrice(); }, child: const Text("Retry"))
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text("No records found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}