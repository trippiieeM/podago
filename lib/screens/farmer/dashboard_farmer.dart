// lib/screens/farmer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Correct package imports
import 'package:podago/widgets/bottom_nav_bar.dart';
import 'package:podago/models/Milk_predictor.dart';
import 'package:podago/services/simple_storage_service.dart';
import 'package:podago/services/pricing_service.dart'; // NEW
import 'package:podago/utils/app_theme.dart'; // NEW
import 'package:podago/screens/auth/role_selection_screen.dart';
import 'package:podago/screens/farmer/feed_request_screen.dart';
import 'package:podago/screens/farmer/support_farmer.dart';
import 'package:podago/screens/farmer/reports_farmer.dart';
import 'package:podago/screens/farmer/history_farmer.dart';

class FarmerDashboard extends StatefulWidget {
  final String farmerId;

  const FarmerDashboard({super.key, required this.farmerId});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  // --- State Variables ---
  String _farmerName = "Loading...";
  double _pricePerLiter = 45.0; 
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // ✅ SAFE DATA LOADING (Prevents blank screens)
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    try {
      // 1. Fetch Name
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.farmerId)
          .get();
          
      // 2. Fetch Price (Centralized Service)
      final price = await PricingService().getCurrentMilkPrice();

      if (mounted) {
        setState(() {
          _farmerName = userDoc.data()?["name"] ?? "Farmer";
          _pricePerLiter = price;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print("Dashboard Error: $e");
      if (mounted) {
        setState(() {
          _farmerName = "Farmer"; // Fallback
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await SimpleStorageService.clearUserSession();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  // --- UI COMPONENTS (Your Components Preserved) ---

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? color : AppTheme.kCardColor,
        gradient: isPrimary ? AppTheme.primaryGradient : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isPrimary ? color.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22, // Adjusted for grid
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: isPrimary ? Colors.white70 : Colors.grey[500],
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isPrimary) Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildPredictionCard({
    required String title,
    required String value,
    required String subtitle,
    required String trend,
    required IconData icon,
    required Color color,
  }) {
    Color trendColor = trend == 'growing' ? Colors.green : (trend == 'declining' ? Colors.red : Colors.grey);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Icon(
                trend == 'growing' ? Icons.trending_up : Icons.trending_flat,
                size: 16,
                color: trendColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildMilkRecordCard(Map<String, dynamic> log, int index) {
    final date = (log["date"] as Timestamp).toDate();
    final quantity = (log['quantity'] ?? 0).toDouble();
    final status = log['status'] ?? 'pending';
    final storedPrice = (log['pricePerLiter'] ?? _pricePerLiter).toDouble();
    final amount = quantity * storedPrice;
    final isPaid = status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.water_drop, color: isPaid ? Colors.green : Colors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${quantity.toStringAsFixed(1)} Liters', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(DateFormat('MMM dd • hh:mm a').format(date), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('KES ${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {'title': 'Request Feed', 'icon': Icons.inventory_2_outlined, 'color': Colors.orange, 'page': FeedRequestScreen(farmerId: widget.farmerId)},
      {'title': 'History', 'icon': Icons.history, 'color': AppTheme.kPrimaryBlue, 'page': FarmerHistoryScreen(farmerId: widget.farmerId)},
      {'title': 'Reports', 'icon': Icons.bar_chart, 'color': Colors.purple, 'page': FarmerReportsScreen(farmerId: widget.farmerId)},
      {'title': 'Support', 'icon': Icons.headset_mic_outlined, 'color': Colors.redAccent, 'page': FarmerSupportScreen(farmerId: widget.farmerId)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => action['page'] as Widget)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (action['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                action['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedRequestCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feed_requests')
          .where('farmerId', isEqualTo: widget.farmerId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        String status = 'Request Feed';
        Color statusColor = AppTheme.kPrimaryGreen;
        IconData statusIcon = Icons.inventory_2_outlined;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final s = data['status'] ?? 'pending';
          if (s == 'pending') { status = 'Pending'; statusColor = Colors.orange; statusIcon = Icons.hourglass_empty; }
          else if (s == 'approved') { status = 'Approved'; statusColor = AppTheme.kSuccess; statusIcon = Icons.check_circle; }
        }

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedRequestScreen(farmerId: widget.farmerId))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.kCardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 12),
                Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    // If loading initial data, show spinner immediately (No blank screen)
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.kBackground,
      appBar: AppBar(
        title: const Text("Podago Cooperative"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("milk_logs")
            .where("farmerId", isEqualTo: widget.farmerId)
            .snapshots(),
        builder: (context, snapshot) {
          // SAFEGUARD: Even if stream waits, show structure, not blank
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data?.docs ?? [];
          final today = DateTime.now();
          
          double todayTotal = 0;
          double monthTotal = 0;
          double pendingTotal = 0;

          for (var doc in logs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data["date"] as Timestamp).toDate();
            final qty = (data["quantity"] ?? 0).toDouble();
            final status = data["status"] ?? "pending";

            if (DateFormat("yyyy-MM-dd").format(date) == DateFormat("yyyy-MM-dd").format(today)) {
              todayTotal += qty;
            }
            if (date.month == today.month && date.year == today.year) {
              monthTotal += qty;
            }
            if (status == "pending") {
              // Use fetched price
              final p = (data['pricePerLiter'] ?? _pricePerLiter).toDouble();
              pendingTotal += qty * p;
            }
          }



          // 🔹 Nested Stream for Deductions to calculate Net Pay
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("payments")
                .where("farmerId", isEqualTo: widget.farmerId)
                .where("type", isEqualTo: "feed_deduction")
                .snapshots(),
            builder: (context, deductionSnapshot) {
               double deductionTotal = 0;
               if (deductionSnapshot.hasData) {
                 for (var doc in deductionSnapshot.data!.docs) {
                   final data = doc.data() as Map<String, dynamic>;
                   if (data['status'] != 'processed') {
                     deductionTotal += (data['amount'] ?? 0).toDouble().abs();
                   }
                 }
               }
               
               final netPending = pendingTotal - deductionTotal;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Welcome
                    Text("Welcome back, $_farmerName", style: AppTheme.displayMedium),
                    Text("Current Price: KES $_pricePerLiter/L", style: AppTheme.bodyMedium),
                    const SizedBox(height: 20),

                    // 2. Stats Grid
                    SizedBox(
                      height: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              icon: Icons.water_drop,
                              title: "Today",
                              value: "${todayTotal.toStringAsFixed(1)}L",
                              subtitle: "Daily yield",
                              color: AppTheme.kPrimaryBlue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryCard(
                              icon: Icons.calendar_month,
                              title: "Month",
                              value: "${monthTotal.toStringAsFixed(0)}L",
                              subtitle: "Total yield",
                              color: AppTheme.kPrimaryGreen,
                              isPrimary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. Pending Payment Banner (Enhanced)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrangeAccent]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Net Pending Pay", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text("After Deductions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text("KES ${netPending.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (deductionTotal > 0) ...[
                            const SizedBox(height: 12),
                            Container(height: 1, color: Colors.white24), // Divider
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Gross Milk Value", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text("KES ${pendingTotal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Feed Deductions", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text("- KES ${deductionTotal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    
                    // NEW: Quick Actions
                    _buildQuickActionsGrid(),

                    const SizedBox(height: 24),
                    // _buildFeedRequestCard(), // Removed in favor of Quick Action, or keep as "Recent Request Status"

                    const SizedBox(height: 30),
                    const Text("AI Forecast", style: AppTheme.titleLarge),
                    const SizedBox(height: 10),

                    FutureBuilder<Map<String, dynamic>>(
                      future: MilkPredictor().predictMilkProduction(widget.farmerId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator(); // Show something while loading
                        
                        final data = snapshot.data!;
                        final daily = data['daily'] as DailyPrediction;
                        final weekly = data['weekly'] as WeeklyPrediction;
                        final monthly = data['monthly'] as MonthlyPrediction;
                        final yearly = data['yearly'] as YearlyPrediction;

                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _buildPredictionCard(title: "Tomorrow", value: "${daily.prediction.toStringAsFixed(1)} L", subtitle: "Conf: ${(daily.confidence*100).toInt()}%", trend: daily.trend, icon: Icons.wb_sunny, color: AppTheme.kPrimaryBlue),
                            _buildPredictionCard(title: "Next Week", value: "${weekly.prediction.toStringAsFixed(0)} L", subtitle: "Estimate", trend: weekly.trend, icon: Icons.calendar_view_week, color: Colors.purple),
                            _buildPredictionCard(title: "Next Month", value: "${monthly.prediction.toStringAsFixed(0)} L", subtitle: "Estimate", trend: monthly.trend, icon: Icons.calendar_month, color: Colors.orange),
                            _buildPredictionCard(title: "Yearly", value: "${(yearly.prediction/1000).toStringAsFixed(1)}k L", subtitle: "Estimate", trend: yearly.trend, icon: Icons.analytics, color: Colors.teal),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    const Text("Recent Transactions", style: AppTheme.titleLarge),
                    const SizedBox(height: 10),
                    
                    if (logs.isEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No records found")))
                    else
                      ...logs.take(5).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final index = logs.indexOf(doc);
                        return _buildMilkRecordCard(data, index);
                      }).toList(),
                      
                    const SizedBox(height: 40),
                  ],
                ),
              );
            }
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        role: "farmer",
        farmerId: widget.farmerId,
      ),
    );
  }
}