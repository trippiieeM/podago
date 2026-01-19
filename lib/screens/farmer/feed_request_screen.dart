import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podago/utils/app_theme.dart';

class FeedRequestScreen extends StatefulWidget {
  final String farmerId;

  const FeedRequestScreen({super.key, required this.farmerId});

  @override
  State<FeedRequestScreen> createState() => _FeedRequestScreenState();
}

class _FeedRequestScreenState extends State<FeedRequestScreen> {
  // --- Logic Variables (Preserved) ---
  String _selectedFeedType = 'Dairy Meal';
  double _selectedQuantity = 25.0;
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableFeeds = [];
  String _errorMessage = '';

  final List<double> _quantityOptions = [25.0, 50.0, 70.0, 100.0, 150.0, 200.0, 300.0, 400.0, 500.0];

  final List<String> _feedTypes = [
    'Dairy Meal', 'Pollard (Wheat Pollard)', 'Maize Germ', 'Maize Bran',
    'Wheat Bran', 'Cottonseed Cake', 'Sunflower Cake', 'Fish Meal',
    'Soybean Meal', 'Molasses', 'Mineral Supplement', 'Salt',
    'Lucerne Meal', 'Urea-Molasses Block', 'Yeast/Probiotic Additives', 'Protein Concentrate'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _fetchAvailableFeeds();
      if(mounted) setState(() { _isLoading = false; });
    } catch (e) {
      if(mounted) setState(() { _errorMessage = 'Failed to load data: $e'; _isLoading = false; });
    }
  }

  Future<void> _fetchAvailableFeeds() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('feeds').get();
      if(mounted) {
        setState(() {
          _availableFeeds = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'type': data['type'] ?? '',
              'quantity': (data['quantity'] ?? 0).toDouble(),
              'availableQuantity': (data['availableQuantity'] ?? data['quantity'] ?? 0).toDouble(),
              'reservedQuantity': (data['reservedQuantity'] ?? 0).toDouble(),
              'unit': data['unit'] ?? 'kg',
              'pricePerUnit': (data['pricePerUnit'] ?? 0).toDouble(),
            };
          }).toList();
        });
      }
    } catch (e) {
      if(mounted) setState(() { _errorMessage = 'Error loading feeds: $e'; });
    }
  }

  Map<String, dynamic> _getStockStatus(Map<String, dynamic> feed) {
    final quantity = feed['quantity'] ?? 0;
    final reserved = feed['reservedQuantity'] ?? 0;
    final available = quantity - reserved;
    
    if (available <= 0) {
      return {'status': 'Out of Stock', 'class': 'out-of-stock', 'available': available};
    } else if (available <= 10) {
      return {'status': 'Low Stock', 'class': 'low-stock', 'available': available};
    } else {
      return {'status': 'In Stock', 'class': 'in-stock', 'available': available};
    }
  }

  bool _isQuantityAvailable(double requestedQuantity) {
    final selectedFeed = _availableFeeds.firstWhere((feed) => feed['type'] == _selectedFeedType, orElse: () => {},);
    if (selectedFeed.isEmpty) return false;
    final stockStatus = _getStockStatus(selectedFeed);
    final available = stockStatus['available'] ?? 0;
    return available >= requestedQuantity;
  }

  double _getAvailableQuantity() {
    final selectedFeed = _availableFeeds.firstWhere((feed) => feed['type'] == _selectedFeedType, orElse: () => {},);
    if (selectedFeed.isEmpty) return 0;
    final stockStatus = _getStockStatus(selectedFeed);
    return (stockStatus['available'] ?? 0).toDouble();
  }

  Future<void> _submitFeedRequest() async {
    if (widget.farmerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Farmer ID not found'), backgroundColor: Colors.red));
      return;
    }

    final selectedFeed = _availableFeeds.firstWhere((feed) => feed['type'] == _selectedFeedType, orElse: () => {},);

    if (selectedFeed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_selectedFeedType is not available in inventory'), backgroundColor: Colors.orange));
      return;
    }

    if (!_isQuantityAvailable(_selectedQuantity)) {
      final available = _getAvailableQuantity();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insufficient stock! Only $available ${selectedFeed['unit']} available'), backgroundColor: Colors.orange));
      return;
    }

    setState(() { _isSubmitting = true; });

    try {
      await FirebaseFirestore.instance.collection('feed_requests').add({
        'farmerId': widget.farmerId,
        'feedType': _selectedFeedType.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll('(', '').replaceAll(')', ''),
        'feedTypeName': _selectedFeedType,
        'quantity': _selectedQuantity,
        'notes': '',
        'status': 'pending',
        'cost': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feed request submitted successfully!'), backgroundColor: AppTheme.kPrimaryGreen));
        setState(() { _selectedFeedType = 'Dairy Meal'; _selectedQuantity = 25.0; });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildScaffold(_buildLoadingState());
    if (_errorMessage.isNotEmpty) return _buildScaffold(_buildErrorState());

    return _buildScaffold(
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Inventory Status ---
            if (_availableFeeds.isNotEmpty) ...[
              const Text("Inventory Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary)),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _availableFeeds.length > 5 ? 5 : _availableFeeds.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _buildStockCard(_availableFeeds[index]),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Order Form ---
            Container(
              decoration: BoxDecoration(
                color: AppTheme.kCardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.kPrimaryGreen.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.add_shopping_cart, color: AppTheme.kPrimaryGreen)),
                      const SizedBox(width: 12),
                      const Text("New Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Feed Type Dropdown
                  const Text("Select Feed", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildDropdown(),

                  const SizedBox(height: 20),

                  // Quantity Grid
                  const Text("Quantity (KG)", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quantityOptions.map((qty) => _buildQuantityChip(qty)).toList(),
                  ),

                  // Validation Message
                  if (!_isQuantityAvailable(_selectedQuantity)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text("Only ${_getAvailableQuantity()} kg available", style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : (_canSubmit() ? _submitFeedRequest : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kPrimaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("SUBMIT ORDER", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- History Section ---
            const Text("Request History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary)),
            const SizedBox(height: 12),
            _buildHistorySection(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Scaffold _buildScaffold(Widget body) {
    return Scaffold(
      backgroundColor: AppTheme.kBackground,
      appBar: AppBar(
        title: const Text("Request Feed"),
      ),
      body: body,
    );
  }

  // --- Components ---

  Widget _buildStockCard(Map<String, dynamic> feed) {
    final status = _getStockStatus(feed);
    final isLow = status['class'] != 'in-stock';
    
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: isLow ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            feed['type'].toString().split('(')[0], // Shorten name
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.kTextPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLow ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${status['available']} kg",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isLow ? Colors.orange.shade800 : AppTheme.kPrimaryGreen),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.kBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFeedType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.kTextSecondary),
          items: _feedTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: const TextStyle(fontSize: 14, color: AppTheme.kTextPrimary)),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedFeedType = value!),
        ),
      ),
    );
  }

  Widget _buildQuantityChip(double qty) {
    final isSelected = _selectedQuantity == qty;
    final isAvailable = _isQuantityAvailable(qty);
    
    return GestureDetector(
      onTap: isAvailable ? () => setState(() => _selectedQuantity = qty) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.kPrimaryGreen : (isAvailable ? Colors.white : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.kPrimaryGreen : (isAvailable ? Colors.grey.shade300 : Colors.transparent)),
          boxShadow: isAvailable && !isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)] : null,
        ),
        child: Text(
          '${qty.toInt()} kg',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (isAvailable ? AppTheme.kTextPrimary : Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('feed_requests').where('farmerId', isEqualTo: widget.farmerId).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyHistory();

        final requests = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) => _buildHistoryItem(requests[index].data() as Map<String, dynamic>),
        );
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> request) {
    final feedType = request['feedTypeName'] ?? 'Unknown';
    final quantity = request['quantity'] ?? 0;
    final status = request['status'] ?? 'pending';
    final date = request['createdAt'] != null ? (request['createdAt'] as Timestamp).toDate() : DateTime.now();
    
    Color statusColor;
    if(status == 'approved') statusColor = Colors.green;
    else if(status == 'rejected') statusColor = Colors.red;
    else if(status == 'delivered') statusColor = Colors.blue;
    else statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.inventory_2_outlined, size: 20, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feedType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.kTextPrimary)),
                const SizedBox(height: 4),
                Text("${quantity}kg • ${DateFormat('MMM dd').format(date)}", style: const TextStyle(fontSize: 12, color: AppTheme.kTextSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
          )
        ],
      ),
    );
  }

  // --- States ---

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGreen));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_errorMessage, style: const TextStyle(color: AppTheme.kTextSecondary), textAlign: TextAlign.center),
          TextButton(onPressed: _initializeData, child: const Text("Retry"))
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.history, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text("No requests yet", style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  bool _canSubmit() => _isQuantityAvailable(_selectedQuantity);
}