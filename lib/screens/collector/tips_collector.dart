import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podago/widgets/bottom_nav_bar.dart';

// --- Model (Preserved) ---
class CollectorTip {
  final String id;
  final String content;
  final String role;
  final DateTime createdAt;
  final bool approved;

  CollectorTip({
    required this.id,
    required this.content,
    required this.role,
    required this.createdAt,
    required this.approved,
  });

  factory CollectorTip.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CollectorTip(
      id: doc.id,
      content: data['content'] ?? '',
      role: data['role'] ?? 'collector',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approved: data['approved'] ?? false,
    );
  }
}

class CollectorTipsScreen extends StatefulWidget {
  const CollectorTipsScreen({super.key});

  @override
  State<CollectorTipsScreen> createState() => _CollectorTipsScreenState();
}

class _CollectorTipsScreenState extends State<CollectorTipsScreen> {
  // --- Professional Theme Colors ---
  static const Color kPrimaryColor = Color(0xFF00695C); // Teal 800
  static const Color kAccentColor = Color(0xFFEF6C00);  // Orange 800 (for tips accent)
  static const Color kBackgroundColor = Color(0xFFF5F7FA);
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF263238);
  static const Color kTextSecondary = Color(0xFF78909C);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<CollectorTip> tips = [];
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
          .where('role', isEqualTo: 'collector')
          .where('approved', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      List<CollectorTip> fetchedTips = snapshot.docs.map((doc) => CollectorTip.fromFirestore(doc)).toList();

      setState(() {
        tips = fetchedTips;
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      print('Error fetching collector tips: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  // ===========================================================================
  // 2. UI SECTION (PROFESSIONAL REDESIGN)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("Collection Guide", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                          // Header Card
                          _buildHeaderCard(),
                          
                          const SizedBox(height: 24),
                          const Text("Latest Procedures", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                          const SizedBox(height: 12),

                          // List
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
      bottomNavigationBar: const BottomNavBar(currentIndex: 2, role: "collector"),
    );
  }

  // --- UI Components ---

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Best Practices", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  "Access ${tips.length} verified protocols for milk collection and handling.",
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(CollectorTip tip, int index) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: kAccentColor, width: 4)), // Orange accent for tips
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: kAccentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text("TIP #${index + 1}", style: const TextStyle(color: kAccentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      if (tip.approved)
                        const Icon(Icons.verified, size: 14, color: kPrimaryColor),
                    ],
                  ),
                  Text(_formatDate(tip.createdAt), style: const TextStyle(color: kTextSecondary, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tip.content,
                style: const TextStyle(fontSize: 14, color: kTextPrimary, height: 1.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("Collection Protocol", style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- States ---

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Unable to load tips", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const Text("Check your internet connection", style: TextStyle(color: kTextSecondary)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _fetchTips,
            style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
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
          const Text("No protocols available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 8),
          const Text("Check back later for updates", style: TextStyle(color: kTextSecondary)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _fetchTips,
            style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            child: const Text("Refresh"),
          )
        ],
      ),
    );
  }
}