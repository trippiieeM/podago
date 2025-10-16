import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';

class FarmerHistoryScreen extends StatefulWidget {
  final String farmerId;

  const FarmerHistoryScreen({super.key, required this.farmerId});

  @override
  State<FarmerHistoryScreen> createState() => _FarmerHistoryScreenState();
}

class _FarmerHistoryScreenState extends State<FarmerHistoryScreen> {
  double _pricePerLiter = 45.0; // Default price, will be updated from admin system
  String _timeFilter = 'all'; // all, day, week, month, year
  bool _isLoadingPrice = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentMilkPrice();
  }

  /// --- Fetch current milk price from admin system ---
  Future<void> _fetchCurrentMilkPrice() async {
    try {
      print('🔄 Fetching current milk price from admin system...');
      
      // Method 1: Check if there's a price configuration in the database
      final priceConfig = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('milk_price')
          .get();

      if (priceConfig.exists) {
        final data = priceConfig.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('pricePerLiter')) {
          setState(() {
            _pricePerLiter = (data['pricePerLiter'] ?? 45.0).toDouble();
            _isLoadingPrice = false;
          });
          print('✅ Milk price loaded from config: KES $_pricePerLiter');
          return;
        }
      }

      // Method 2: Get the latest price used in recent payments
      final recentPayments = await FirebaseFirestore.instance
          .collection('payments')
          .where('type', isEqualTo: 'milk_payment')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (recentPayments.docs.isNotEmpty) {
        final paymentData = recentPayments.docs.first.data() as Map<String, dynamic>;
        if (paymentData.containsKey('pricePerLiter')) {
          setState(() {
            _pricePerLiter = (paymentData['pricePerLiter'] ?? 45.0).toDouble();
            _isLoadingPrice = false;
          });
          print('✅ Milk price loaded from recent payment: KES $_pricePerLiter');
          return;
        }
      }

      // Method 3: Get price from recent milk logs
      final recentMilkLogs = await FirebaseFirestore.instance
          .collection('milk_logs')
          .where('status', isEqualTo: 'paid')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (recentMilkLogs.docs.isNotEmpty) {
        final milkData = recentMilkLogs.docs.first.data() as Map<String, dynamic>;
        if (milkData.containsKey('pricePerLiter')) {
          setState(() {
            _pricePerLiter = (milkData['pricePerLiter'] ?? 45.0).toDouble();
            _isLoadingPrice = false;
          });
          print('✅ Milk price loaded from milk log: KES $_pricePerLiter');
          return;
        }
      }

      // Fallback to default price
      setState(() {
        _pricePerLiter = 45.0;
        _isLoadingPrice = false;
      });
      print('ℹ️ Using default milk price: KES $_pricePerLiter');

    } catch (error) {
      print('❌ Error fetching milk price: $error');
      setState(() {
        _pricePerLiter = 45.0;
        _isLoadingPrice = false;
      });
      print('ℹ️ Using fallback milk price: KES $_pricePerLiter');
    }
  }

  /// --- Filter Helper ---
  List<DocumentSnapshot> _applyFilter(List<DocumentSnapshot> docs) {
    if (_timeFilter == 'all') return docs;

    final now = DateTime.now();
    late DateTime startDate;

    switch (_timeFilter) {
      case 'day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(2000);
    }

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      return date.isAfter(startDate);
    }).toList();
  }

  /// --- UPDATED: Fetch Payment Data from Admin System ---
  Future<Map<String, dynamic>> _fetchPaymentData() async {
    try {
      print('🔄 Fetching payment data for farmer: ${widget.farmerId}');
      
      // Fetch ALL payments for this farmer (both milk payments and feed deductions)
      final paymentsQuery = FirebaseFirestore.instance
          .collection('payments')
          .where('farmerId', isEqualTo: widget.farmerId)
          .orderBy('createdAt', descending: true);

      final paymentsSnapshot = await paymentsQuery.get();
      print('📄 Found ${paymentsSnapshot.docs.length} total payment documents');

      // Separate milk payments and feed deductions
      final milkPayments = paymentsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['type'] == 'milk_payment';
      }).toList();

      final feedDeductions = paymentsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['type'] == 'feed_deduction' && data['status'] != 'processed';
      }).toList();

      // Also fetch milk logs to calculate current balance
      final milkLogsQuery = FirebaseFirestore.instance
          .collection('milk_logs')
          .where('farmerId', isEqualTo: widget.farmerId)
          .orderBy('date', descending: true);

      final milkLogsSnapshot = await milkLogsQuery.get();

      print('💰 Milk Payments: ${milkPayments.length}');
      print('🌾 Feed Deductions: ${feedDeductions.length}');
      print('🥛 Milk Logs: ${milkLogsSnapshot.docs.length}');

      return {
        'milkPayments': milkPayments,
        'feedDeductions': feedDeductions,
        'milkLogs': milkLogsSnapshot.docs,
      };
    } catch (error) {
      print('❌ Error fetching payment data: $error');
      return {
        'milkPayments': [],
        'feedDeductions': [],
        'milkLogs': [],
      };
    }
  }

  /// --- UPDATED: Calculate Totals - Deductions ONLY from Pending ---
  Map<String, double> _calculatePaymentTotals(Map<String, dynamic> paymentData) {
    final milkPayments = paymentData['milkPayments'] as List<DocumentSnapshot>;
    final feedDeductions = paymentData['feedDeductions'] as List<DocumentSnapshot>;
    final milkLogs = paymentData['milkLogs'] as List<DocumentSnapshot>;

    print('🧮 Calculating totals - deductions ONLY from pending:');
    print('   Milk Payments: ${milkPayments.length}');
    print('   Feed Deductions: ${feedDeductions.length}');
    print('   Milk Logs: ${milkLogs.length}');
    print('   Current Price: KES $_pricePerLiter per liter');

    // Separate milk logs into paid and pending
    final paidMilkLogs = milkLogs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'paid';
    }).toList();

    final pendingMilkLogs = milkLogs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'pending';
    }).toList();

    print('   Paid Milk Logs: ${paidMilkLogs.length}');
    print('   Pending Milk Logs: ${pendingMilkLogs.length}');

    // Calculate total milk income from paid milk logs (NEVER TOUCHED BY DEDUCTIONS)
    double totalMilkIncome = paidMilkLogs.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Use stored price if available, otherwise use current price
      final price = (data['pricePerLiter'] ?? _pricePerLiter).toDouble();
      final amount = (data['quantity'] ?? 0).toDouble() * price;
      return sum + amount;
    });

    // If no paid milk logs found, use admin payment records as fallback
    if (totalMilkIncome == 0 && milkPayments.isNotEmpty) {
      print('⚠️ No paid milk logs found, using admin payment records');
      totalMilkIncome = milkPayments.fold(0.0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        return sum + (data['amount'] ?? 0.0);
      });
    }

    // Calculate pending milk value (unpaid milk logs) - always use current price
    double totalPendingMilk = pendingMilkLogs.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return sum + ((data['quantity'] ?? 0).toDouble() * _pricePerLiter);
    });

    // Calculate total feed deductions
    double totalFeedDeductions = feedDeductions.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = data['amount'] ?? 0.0;
      return sum + (amount < 0 ? amount.abs() : amount);
    });

    // **UPDATED DEDUCTION LOGIC: ONLY FROM PENDING, NEVER FROM PAID**
    double deductionsAppliedToPending = 0.0;
    double remainingPendingAfterDeductions = 0.0;

    if (totalFeedDeductions > 0 && totalPendingMilk > 0) {
      // Apply deductions ONLY to pending milk
      if (totalFeedDeductions <= totalPendingMilk) {
        // All deductions can be covered by pending milk
        deductionsAppliedToPending = totalFeedDeductions;
        remainingPendingAfterDeductions = totalPendingMilk - totalFeedDeductions;
      } else {
        // Deductions exceed pending milk - ONLY deduct up to pending amount
        deductionsAppliedToPending = totalPendingMilk;
        remainingPendingAfterDeductions = 0.0;
      }
    } else {
      // No deductions or no pending milk
      deductionsAppliedToPending = 0.0;
      remainingPendingAfterDeductions = totalPendingMilk;
    }

    print('🎯 DEDUCTION BREAKDOWN (PENDING ONLY):');
    print('   Total Feed Deductions: KES $totalFeedDeductions');
    print('   Applied to Pending Milk: KES $deductionsAppliedToPending');
    print('   Remaining Pending Milk: KES $remainingPendingAfterDeductions');
    print('   Paid Milk (PROTECTED): KES $totalMilkIncome');
    print('🎯 FINAL TOTALS:');
    print('   Milk Income: KES $totalMilkIncome');
    print('   Pending Milk: KES $totalPendingMilk');
    print('   Feed Deductions: KES $totalFeedDeductions');
    print('   Remaining Pending: KES $remainingPendingAfterDeductions');

    return {
      'totalMilkIncome': totalMilkIncome,
      'totalPendingMilk': totalPendingMilk,
      'totalFeedDeductions': totalFeedDeductions,
      'remainingPendingAfterDeductions': remainingPendingAfterDeductions,
      'deductionsAppliedToPending': deductionsAppliedToPending,
    };
  }

  /// --- States ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Payment History',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingPrice)
            Text(
              'Fetching current milk price...',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Payment History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error.contains('index') 
                ? 'Database is being set up. Please wait a few minutes and try again.'
                : error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingPrice = true;
                });
                _fetchCurrentMilkPrice();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payments_outlined,
                size: 60,
                color: Colors.green.shade400,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              'No Payment Records Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment history will appear here\nonce payments are processed by admin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingPrice = true;
                });
                _fetchCurrentMilkPrice();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    Map<String, double>? paymentTotals,
  }) {
    // Special handling for remaining pending to show deduction breakdown
    Widget? additionalInfo;
    
    if (title.contains("REMAINING PENDING") && paymentTotals != null) {
      final deductionsToPending = paymentTotals['deductionsAppliedToPending'] ?? 0;
      final originalPending = paymentTotals['totalPendingMilk'] ?? 0;
      
      if (deductionsToPending > 0) {
        additionalInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'After KES ${deductionsToPending.toStringAsFixed(0)} in deductions',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
              ),
            ),
            if (originalPending > 0)
              Text(
                'From KES ${originalPending.toStringAsFixed(0)} total pending',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.green.shade600,
                ),
              ),
          ],
        );
      }
    }

    // Special handling for pending milk to show deduction impact
    if (title.contains("PENDING MILK") && paymentTotals != null) {
      final deductionsToPending = paymentTotals['deductionsAppliedToPending'] ?? 0;
      
      if (deductionsToPending > 0) {
        additionalInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'KES ${deductionsToPending.toStringAsFixed(0)} will be used for deductions',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orange.shade600,
              ),
            ),
          ],
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          )),
                      Text(value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          )),
                      Text(subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          )),
                      if (additionalInfo != null) additionalInfo,
                      if (title.contains("MILK"))
                        Text(
                          "@ KES $_pricePerLiter/L",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 4),
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Day', 'day'),
            const SizedBox(width: 8),
            _buildFilterChip('Week', 'week'),
            const SizedBox(width: 8),
            _buildFilterChip('Month', 'month'),
            const SizedBox(width: 8),
            _buildFilterChip('Year', 'year'),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRecordCard(DocumentSnapshot doc, int index, String type) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['createdAt'] ?? data['date'] as Timestamp).toDate();
    final amount = (data['amount'] ?? 0).toDouble();
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'completed';
    final priceUsed = (data['pricePerLiter'] ?? _pricePerLiter).toDouble();

    final isDeduction = type == 'feed_deduction' || amount < 0;
    final amountColor = isDeduction ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDeduction 
                            ? Colors.red.shade50 
                            : Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDeduction ? Icons.shopping_bag : Icons.payments,
                        color: isDeduction ? Colors.red.shade600 : Colors.green.shade600,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDeduction ? 'Feed Deduction' : 'Milk Payment',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (!isDeduction)
                            Text(
                              'Price: KES $priceUsed/L',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'completed' || status == 'paid'
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'completed' || status == 'paid'
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status == 'completed' || status == 'paid'
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      isDeduction ? Icons.remove : Icons.add,
                      'KES ${amount.abs().toStringAsFixed(0)}',
                      amountColor,
                    ),
                    const SizedBox(width: 8),
                    if (description.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilkRecordCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data["date"] as Timestamp).toDate();
    final quantity = (data['quantity'] ?? 0).toDouble();
    final status = data['status'] ?? 'pending';
    final notes = data['notes'] ?? 'No additional notes';
    
    // Use stored price if available, otherwise use current price
    final price = (data['pricePerLiter'] ?? _pricePerLiter).toDouble();
    final amount = quantity * price;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_drink,
                          color: Colors.blue.shade600, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery #${index + 1}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Price: KES $price/L',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'paid'
                            ? Colors.green.shade50
                            : status == 'deducted'
                            ? Colors.orange.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'paid'
                              ? Colors.green.shade200
                              : status == 'deducted'
                              ? Colors.orange.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status == 'paid'
                              ? Colors.green.shade600
                              : status == 'deducted'
                              ? Colors.orange.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(Icons.water_drop,
                        '${quantity.toStringAsFixed(1)} L', Colors.blue.shade600),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.attach_money,
                        'KES ${amount.toStringAsFixed(0)}', 
                        status == 'paid' ? Colors.green.shade600 : 
                        status == 'deducted' ? Colors.orange.shade600 : 
                        Colors.grey.shade600),
                  ],
                ),
                if (notes.isNotEmpty && notes != 'No additional notes') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Payment & Delivery History",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                setState(() {
                  _isLoadingPrice = true;
                });
                _fetchCurrentMilkPrice();
              },
              tooltip: 'Refresh History'),
        ],
      ),
      body: _isLoadingPrice 
          ? _buildLoadingState()
          : FutureBuilder<Map<String, dynamic>>(
              future: _fetchPaymentData(),
              builder: (context, paymentSnapshot) {
                if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                if (paymentSnapshot.hasError) {
                  return _buildErrorState(paymentSnapshot.error.toString());
                }

                final paymentData = paymentSnapshot.data ?? {
                  'milkPayments': [],
                  'feedDeductions': [],
                  'milkLogs': [],
                };

                final paymentTotals = _calculatePaymentTotals(paymentData);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("milk_logs")
                      .where("farmerId", isEqualTo: widget.farmerId)
                      .orderBy("date", descending: true)
                      .snapshots(),
                  builder: (context, milkSnapshot) {
                    if (milkSnapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }
                    if (milkSnapshot.hasError) {
                      return _buildErrorState(milkSnapshot.error.toString());
                    }
                    if (!milkSnapshot.hasData || milkSnapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    /// Apply filter to milk logs
                    final filteredLogs = _applyFilter(milkSnapshot.data!.docs);

                    if (filteredLogs.isEmpty) return _buildEmptyState();

                    /// Calculate milk delivery totals
                    double totalLiters = filteredLogs.fold(0.0, (sum, log) {
                      final data = log.data() as Map<String, dynamic>;
                      return sum + (data["quantity"] ?? 0).toDouble();
                    });

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Price Info Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.price_change, color: Colors.blue.shade700, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Current Milk Price: KES $_pricePerLiter per liter',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Deduction Priority Info
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.security, color: Colors.green.shade700, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Deductions ONLY applied to pending milk. Paid amounts are protected.',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Payment Summary Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildTimeFilter(),
                                const SizedBox(height: 16),
                                _buildSummaryCard(
                                  icon: Icons.local_drink,
                                  title: "TOTAL MILK DELIVERED",
                                  value: "${totalLiters.toStringAsFixed(1)} L",
                                  subtitle: "Across ${filteredLogs.length} deliveries",
                                  color: Colors.blue,
                                ),
                                _buildSummaryCard(
                                  icon: Icons.payments,
                                  title: "TOTAL MILK INCOME",
                                  value: "KES ${paymentTotals['totalMilkIncome']!.toStringAsFixed(0)}",
                                  subtitle: "Paid milk payments (protected)",
                                  color: Colors.green,
                                ),
                                _buildSummaryCard(
                                  icon: Icons.pending_actions,
                                  title: "PENDING MILK",
                                  value: "KES ${paymentTotals['totalPendingMilk']!.toStringAsFixed(0)}",
                                  subtitle: "Awaiting payment",
                                  color: Colors.orange,
                                  paymentTotals: paymentTotals,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(
                                        icon: Icons.shopping_bag,
                                        title: "FEED DEDUCTIONS",
                                        value: "KES ${paymentTotals['totalFeedDeductions']!.toStringAsFixed(0)}",
                                        subtitle: "Total feed costs",
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSummaryCard(
                                        icon: Icons.account_balance_wallet,
                                        title: "REMAINING PENDING",
                                        value: "KES ${paymentTotals['remainingPendingAfterDeductions']!.toStringAsFixed(0)}",
                                        subtitle: "After feed deductions",
                                        color: Colors.purple,
                                        paymentTotals: paymentTotals,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.grey.shade200,
                          ),

                          // Payment History Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.payment, color: Colors.green.shade600, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "PAYMENT HISTORY",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),

                          // Payment Records
                          Column(
                            children: [
                              // Show milk payments from admin system
                              ...paymentData['milkPayments'].map<Widget>((doc) => 
                                _buildPaymentRecordCard(doc, 0, 'milk_payment')
                              ).toList(),
                              
                              // Show feed deductions from admin system
                              ...paymentData['feedDeductions'].map<Widget>((doc) => 
                                _buildPaymentRecordCard(doc, 0, 'feed_deduction')
                              ).toList(),
                            ],
                          ),

                          // Delivery History Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.history, color: Colors.blue.shade600, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "DELIVERY HISTORY (${filteredLogs.length})",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),

                          // Milk delivery records
                          Column(
                            children: filteredLogs.asMap().entries.map((entry) => 
                              _buildMilkRecordCard(entry.value, entry.key)
                            ).toList(),
                          ),

                          // Add some bottom padding to account for the navigation bar
                          const SizedBox(height: 80),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        role: "farmer",
        farmerId: widget.farmerId,
      ),
    );
  }
}