import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart'; // Ensure this is in pubspec.yaml
import 'package:share_plus/share_plus.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';
import 'package:podago/utils/app_theme.dart'; // NEW
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class FarmerReportsScreen extends StatefulWidget {
  final String farmerId;

  const FarmerReportsScreen({super.key, required this.farmerId});

  @override
  State<FarmerReportsScreen> createState() => _FarmerReportsScreenState();
}

class _FarmerReportsScreenState extends State<FarmerReportsScreen> with SingleTickerProviderStateMixin {
  // --- Constants ---
  // Using AppTheme

  // --- State Variables ---
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  late TabController _tabController;

  // Data Containers
  List<DocumentSnapshot> _milkLogs = [];
  List<DocumentSnapshot> _payments = [];
  
  // Totals
  double _totalProduction = 0;
  double _totalIncome = 0;
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Default to current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    _selectedDateRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
    
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end.add(const Duration(days: 1)); // Include the full end day

      // 1. Fetch Milk Logs
      final milkQuery = await FirebaseFirestore.instance
          .collection('milk_logs')
          .where('farmerId', isEqualTo: widget.farmerId)
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .orderBy('date', descending: false)
          .get();

      // 2. Fetch Payments
      final paymentQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('farmerId', isEqualTo: widget.farmerId)
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end)
          .orderBy('createdAt', descending: false)
          .get();

      if (!mounted) return;

      setState(() {
        _milkLogs = milkQuery.docs;
        _payments = paymentQuery.docs;
        _calculateTotals();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching report data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        // Helpful error if indexes are missing
        if (e.toString().contains('failed-precondition')) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing Index: Check debug console for link")));
        }
      }
    }
  }

  void _calculateTotals() {
    _totalProduction = 0;
    _totalIncome = 0;
    _totalExpenses = 0;

    for (var doc in _milkLogs) {
      final data = doc.data() as Map<String, dynamic>;
      _totalProduction += (data['quantity'] ?? 0).toDouble();
    }

    for (var doc in _payments) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      final type = data['type'];

      if (type == 'milk_payment') {
        _totalIncome += amount;
      } else if (type == 'feed_deduction' || type == 'expense') {
        _totalExpenses += amount.abs();
      }
    }
  }

  // --- FIX: Date Picker Logic ---
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      // FIX: lastDate must be far in the future (2100) so it doesn't conflict 
      // with initialDateRange if the month hasn't finished yet.
      lastDate: DateTime(2100), 
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.kPrimaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchData();
    }
  }

  Future<String> _generateCSV() async {
    List<List<dynamic>> rows = [];
    rows.add(["Date", "Type", "Description", "Quantity (L)", "Credit (KES)", "Debit (KES)"]);

    for (var doc in _milkLogs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(date),
        "Production",
        "Milk Delivery",
        data['quantity'],
        "-",
        "-"
      ]);
    }

    for (var doc in _payments) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['createdAt'] as Timestamp).toDate();
      final type = data['type'];
      final isIncome = type == 'milk_payment';
      
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(date),
        isIncome ? "Payment" : "Deduction",
        data['description'] ?? type,
        "-",
        isIncome ? data['amount'] : "-",
        !isIncome ? data['amount'] : "-"
      ]);
    }

    rows.add([]);
    rows.add(["SUMMARY REPORT", "${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} to ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}"]);
    rows.add(["Total Yield", _totalProduction]);
    rows.add(["Net Income", (_totalIncome - _totalExpenses)]);

    return const ListToCsvConverter().convert(rows);
  }

  // --- NEW FEATURE: Direct Download ---
  Future<void> _downloadDirectly() async {
    try {
      final csvData = await _generateCSV();
      final fileName = "Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";
      
      String? savePath;
      
      if (Platform.isAndroid) {
        // Try to save to the public "Download" folder
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          savePath = "${directory.path}/$fileName";
        } else {
          // Fallback to external storage if Download folder not found (rare)
          final fallbackDir = await getExternalStorageDirectory();
          savePath = "${fallbackDir?.path}/$fileName";
        }
      } else {
        // iOS: Save to Documents directory
        final directory = await getApplicationDocumentsDirectory();
        savePath = "${directory.path}/$fileName";
      }

      if (savePath == null) throw "Could not determine save path";

      final file = File(savePath);
      await file.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved to: $savePath"),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: "OK", onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e")),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    try {
      final csvData = await _generateCSV();
      final directory = await getTemporaryDirectory();
      final fileName = "Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsString(csvData);
      
      await Share.shareXFiles(
        [XFile(path)], 
        text: 'Farmer Report: ${DateFormat('MMM yyyy').format(_selectedDateRange!.start)}'
      );
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- PDF Generation ---
  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    
    // Calculate summaries
    final production = _totalProduction.toStringAsFixed(1);
    final income = _totalIncome.toStringAsFixed(0);
    final expenses = _totalExpenses.toStringAsFixed(0);
    final net = (_totalIncome - _totalExpenses).toStringAsFixed(0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Farmer Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "Period: ${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}",
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            
            // Summary Table
            pw.Table.fromTextArray(
              context: context,
              headers: ['Total Yield (L)', 'Total Income (KES)', 'Total Expenses (KES)', 'Net Income (KES)'],
              data: [
                [production, income, expenses, net]
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellAlignment: pw.Alignment.center,
            ),
            
            pw.SizedBox(height: 30),
            pw.Text("Detailed Transactions", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Logs Table
            pw.Table.fromTextArray(
              context: context,
              headers: ['Date', 'Type', 'Description', 'Amount / Qty'],
              data: [
                // Milk Logs
                ..._milkLogs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp).toDate();
                  return [
                    DateFormat('yyyy-MM-dd').format(date),
                    'Production',
                    'Milk Delivery',
                    '${data['quantity']} L'
                  ];
                }),
                // Payments
                ..._payments.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = (data['createdAt'] as Timestamp).toDate();
                  final type = data['type'];
                  final amount = (data['amount'] ?? 0).toDouble();
                  return [
                    DateFormat('yyyy-MM-dd').format(date),
                    type == 'milk_payment' ? 'Payment' : 'Deduction',
                    data['description'] ?? type,
                    'KES ${amount.abs().toStringAsFixed(0)}'
                  ];
                }),
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Farmer_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kBackground,
      appBar: AppBar(
        title: const Text("Analytics"),
        actions: [
          // Date Picker Button
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDateRange,
            tooltip: "Filter Date",
          ),
          // NEW: Direct Download Button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadDirectly,
            tooltip: "Save CSV",
          ),
          // PDF Button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePDF,
            tooltip: "Export PDF",
          ),
          // Share Button
          // Share Button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: "Share CSV",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGreen))
          : Column(
              children: [
                // Date Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        "${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}",
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text("${_milkLogs.length + _payments.length} Records", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),

                // Cards Row
                SizedBox(
                  height: 130,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildGradientCard("Total Yield", "${_totalProduction.toStringAsFixed(1)} L", Icons.water_drop, AppTheme.kPrimaryBlue),
                      const SizedBox(width: 12),
                      _buildGradientCard("Total Earned", "KES ${_totalIncome.toStringAsFixed(0)}", Icons.monetization_on, AppTheme.kPrimaryGreen),
                      const SizedBox(width: 12),
                      _buildGradientCard("Expenses", "KES ${_totalExpenses.toStringAsFixed(0)}", Icons.trending_down, AppTheme.kWarning),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.kPrimaryBlue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.kPrimaryBlue,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: "Production Trend"),
                      Tab(text: "Financial Overview"),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Charts Area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChartContainer(_buildProductionLineChart()),
                      _buildChartContainer(_buildFinancialBarChart()),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        role: "farmer",
        farmerId: widget.farmerId,
      ),
    );
  }

  // --- Helper Widgets (No Changes Logic) ---

  Widget _buildGradientCard(String title, String value, IconData icon, Color baseColor) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, baseColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: baseColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChartContainer(Widget chart) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.only(right: 16, left: 0, top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: chart,
    );
  }

  Widget _buildProductionLineChart() {
    if (_milkLogs.isEmpty) return _buildEmptyState("No production records for this period");

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (_milkLogs.length / 5).ceil().toDouble() == 0 ? 1 : (_milkLogs.length / 5).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < _milkLogs.length) {
                  final date = (_milkLogs[index]['date'] as Timestamp).toDate();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                }
                return const Text("");
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final date = (_milkLogs[touchedSpot.x.toInt()]['date'] as Timestamp).toDate();
                return LineTooltipItem(
                  "${DateFormat('MMM dd').format(date)}\n",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: "${touchedSpot.y} L",
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_milkLogs.length, (index) {
              final qty = (_milkLogs[index]['quantity'] ?? 0).toDouble();
              return FlSpot(index.toDouble(), qty);
            }),
            isCurved: true,
            color: AppTheme.kPrimaryGreen,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppTheme.kPrimaryGreen.withOpacity(0.3), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBarChart() {
    if (_payments.isEmpty) return _buildEmptyState("No financial records for this period");
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_totalIncome > _totalExpenses ? _totalIncome : _totalExpenses) * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
               String type = group.x == 0 ? "Income" : "Expense";
               return BarTooltipItem(
                 "$type\n",
                 const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 children: [TextSpan(text: "KES ${rod.toY.toStringAsFixed(0)}", style: const TextStyle(color: Colors.yellow))],
               );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text("Income", style: TextStyle(fontWeight: FontWeight.bold)));
                if (value == 1) return const Padding(padding: EdgeInsets.only(top: 8), child: Text("Expenses", style: TextStyle(fontWeight: FontWeight.bold)));
                return const Text("");
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [BarChartRodData(toY: _totalIncome, color: AppTheme.kSecondaryGreen, width: 30, borderRadius: BorderRadius.circular(4))],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [BarChartRodData(toY: _totalExpenses, color: Colors.orangeAccent, width: 30, borderRadius: BorderRadius.circular(4))],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}