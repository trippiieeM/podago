import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';

class FarmerTipsScreen extends StatefulWidget {
  final String farmerId;

  const FarmerTipsScreen({super.key, required this.farmerId});

  @override
  State<FarmerTipsScreen> createState() => _FarmerTipsScreenState();
}

class _FarmerTipsScreenState extends State<FarmerTipsScreen> {
  // --- Professional Theme Colors ---
  static const Color kPrimaryGreen = Color(0xFF1B5E20); // Deep Emerald
  static const Color kBackground = Color(0xFFF3F5F7);   // Light Grey-Blue
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF757575);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> tips = [];
  bool isLoading = true;
  bool hasError = false;

  // ===========================================================================
  // 1. LOGIC SECTION (STRICTLY PRESERVED)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _fetchTips();
  }

  Future<void> _fetchTips() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('tips')
          .where('role', isEqualTo: 'farmer')
          .where('approved', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> fetchedTips = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['content'] != null) {
          fetchedTips.add({
            'content': data['content'],
            'createdAt': data['createdAt'],
            'id': doc.id,
          });
        }
      }

      setState(() {
        tips = fetchedTips;
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      print('Error fetching tips: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  String _formatDate(Timestamp timestamp) {
    try {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate());
    } catch (e) {
      return 'Recent';
    }
  }

  // ===========================================================================
  // 2. UI SECTION (PROFESSIONAL REDESIGN)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text("Knowledge Hub", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kTextSecondary),
            onPressed: _fetchTips,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : hasError
              ? _buildErrorState()
              : tips.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Header Card ---
                          _buildHeaderCard(),
                          const SizedBox(height: 24),
                          
                          const Text("Latest Insights", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                          const SizedBox(height: 12),

                          // --- Tips List ---
                          Expanded(
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: tips.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildTipCard(tips[index], index);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        role: "farmer",
        farmerId: widget.farmerId,
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryGreen, kPrimaryGreen.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: kPrimaryGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Grow your farm", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  "Access ${tips.length} expert tips curated for better yield and herd health.",
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip, int index) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: kPrimaryGreen, width: 4)), // Professional accent strip
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("TIP #${index + 1}", style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (tip['createdAt'] != null)
                      Text(
                        _formatDate(tip['createdAt'] as Timestamp),
                        style: const TextStyle(color: kTextSecondary, fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tip['content'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: kTextPrimary,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 20, color: Colors.grey.shade300),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- State Widgets ---

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: kPrimaryGreen));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Could not load tips", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const Text("Check your connection", style: TextStyle(color: kTextSecondary)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _fetchTips,
            style: TextButton.styleFrom(foregroundColor: kPrimaryGreen),
            child: const Text("Try Again"),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No tips available yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextSecondary)),
          const SizedBox(height: 8),
          const Text("Check back later for updates", style: TextStyle(color: kTextSecondary, fontSize: 12)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _fetchTips,
            style: TextButton.styleFrom(foregroundColor: kPrimaryGreen),
            child: const Text("Refresh"),
          )
        ],
      ),
    );
  }
}