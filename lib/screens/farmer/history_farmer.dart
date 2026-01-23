import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';
import 'package:podago/services/pricing_service.dart';
import 'package:podago/utils/app_theme.dart';

class FarmerHistoryScreen extends StatefulWidget {
  final String farmerId;

  const FarmerHistoryScreen({super.key, required this.farmerId});

  @override
  State<FarmerHistoryScreen> createState() => _FarmerHistoryScreenState();
}

class _FarmerHistoryScreenState extends State<FarmerHistoryScreen> {
  // --- Standardizing Colors to AppTheme ---
  
  // --- Logic Variables ---
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
    final price = await PricingService().getCurrentMilkPrice();
    if (mounted) {
      setState(() {
        _pricePerLiter = price;
        _isLoadingPrice = false;
      });
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
        return data['type'] == 'feed_deduction' && data['status'] != 'processed'; // Show only pending/active deductions here or all? Logic says != processed usually means active. But for history we might want all? 
        // Logic check: Previously it was 'status' != 'processed'. Wait, usually processed means "done/paid". 
        // If we want history, we should probably show ALL deductions? 
        // But the previous code had `&& data['status'] != 'processed'`. 
        // Let's stick to previous code logic to be safe, but "History" usually implies everything.
        // However, `processPayment` creates a PAYMENT record. 
        // Maybe these are separate "Deduction requests" vs "Deduction payments". 
        // Let's trust the previous logic which filtered them. 
        return true; // actually, for history, let's show ALL. 
        // Wait, the previous code was: return data['type'] == 'feed_deduction' && data['status'] != 'processed';
        // If I change it, I might break something. Let's look at the previous code again on line 74 of the original file.
        // It says `return data['type'] == 'feed_deduction' && data['status'] != 'processed';`
        // I will keep it identical to ensure I don't introduce a regression in logic I don't fully understand yet.
      }).toList();
      
      // Actually, checking line 74 again...
      // `final feedDeductions = paymentsSnapshot.docs.where((doc) { ... return data['type'] == 'feed_deduction' && data['status'] != 'processed'; }).toList();`
      // This is consistent. I will stick to it.

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.kBackground,
        appBar: AppBar(
          title: const Text("History"),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppTheme.kPrimaryGreen,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Milk Collections"),
              Tab(text: "Transactions"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
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
                      final docs = milkSnapshot.hasData ? milkSnapshot.data!.docs : <DocumentSnapshot>[];
                      final filteredLogs = _applyFilter(docs);
  
                      return TabBarView(
                        children: [
                          // --- Tab 1: Milk Collections ---
                          _buildMilkCollectionsTab(filteredLogs),
  
                          // --- Tab 2: Financial Transactions ---
                          _buildTransactionsTab(paymentData, paymentTotals),
                        ],
                      );
                    },
                  );
                },
              ),
        bottomNavigationBar: BottomNavBar(currentIndex: 1, role: "farmer", farmerId: widget.farmerId),
      ),
    );
  }

  // --- HELPER: Group by Month ---
  Map<String, List<DocumentSnapshot>> _groupDocumentsByMonth(List<DocumentSnapshot> docs) {
    final Map<String, List<DocumentSnapshot>> groups = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Handle 'date' (Milk) or 'createdAt' (Payments)
      final Timestamp? timestamp = data['date'] ?? data['createdAt'];
      if (timestamp == null) continue;

      final date = timestamp.toDate();
      final key = DateFormat('MMMM yyyy').format(date);

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(doc);
    }
    return groups;
  }

  // --- TABS ---

  Widget _buildMilkCollectionsTab(List<DocumentSnapshot> filteredLogs) {
    if (filteredLogs.isEmpty) return _buildEmptyState("No milk records found");

    final groupedLogs = _groupDocumentsByMonth(filteredLogs);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceHeader(),
          const SizedBox(height: 16),
          _buildTimeFilter(),
          const SizedBox(height: 20),
          _buildSectionTitle("Milk Logs"),
          const SizedBox(height: 12),
          
          ...groupedLogs.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMonthHeader(entry.key),
                ...entry.value.map((doc) => _buildMilkRecordCard(doc, 0)),
                const SizedBox(height: 16), // Spacing between months
              ],
            );
          }),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(Map<String, dynamic> paymentData, Map<String, double> paymentTotals) {
    final milkPayments = paymentData['milkPayments'] as List<DocumentSnapshot>;
    final feedDeductions = paymentData['feedDeductions'] as List<DocumentSnapshot>;
    
    // Combine and Sort Transactions
    final List<DocumentSnapshot> allTransactions = [...milkPayments, ...feedDeductions];
    allTransactions.sort((a, b) {
      final da = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp;
      final db = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp;
      return db.compareTo(da); // Descending
    });

    final hasTransactions = allTransactions.isNotEmpty;
    final groupedTransactions = _groupDocumentsByMonth(allTransactions);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // --- Financial Summary Grid ---
          _buildSectionTitle("Financial Overview"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryCard(
                title: "Total Paid", 
                value: "KES ${NumberFormat.compact().format(paymentTotals['totalMilkIncome'])}",
                subtitle: "Realized Income",
                icon: Icons.verified_user_outlined, 
                color: AppTheme.kPrimaryGreen
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard(
                title: "Deductions", 
                value: "KES ${NumberFormat.compact().format(paymentTotals['totalFeedDeductions'])}", 
                subtitle: "Feed Items",
                icon: Icons.shopping_bag_outlined, 
                color: Colors.redAccent
              )),
            ],
          ),
          const SizedBox(height: 12),
          _buildNetPendingCard(paymentTotals),
          
          const SizedBox(height: 24),
          _buildSectionTitle("Transaction History"),
          const SizedBox(height: 12),

          if (!hasTransactions)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text("No financial transactions yet", style: TextStyle(color: Colors.grey))),
            ),

          if (hasTransactions)
            ...groupedTransactions.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthHeader(entry.key),
                  ...entry.value.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'] ?? 'milk_payment'; 
                    return _buildPaymentRecordCard(doc, 0, type);
                  }),
                  const SizedBox(height: 16),
                ],
              );
            }),
              
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
  
  Widget _buildMonthHeader(String monthYear) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.kPrimaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          monthYear.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.kPrimaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
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
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.kTextPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.kTextSecondary)),
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
          color: isSelected ? AppTheme.kPrimaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.kPrimaryGreen : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.kPrimaryGreen.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
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
    final isDeduction = type == 'feed_deduction' || amount < 0; // Logic for deduction

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
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
              Text(DateFormat('MMM dd • hh:mm a').format(date), style: const TextStyle(color: AppTheme.kTextSecondary, fontSize: 11)),
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
        color: AppTheme.kCardColor,
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
                Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(color: AppTheme.kTextSecondary, fontSize: 11)),
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
    return const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGreen));
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}