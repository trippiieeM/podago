// lib/screens/feed_request_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FeedRequestScreen extends StatefulWidget {
  final String farmerId;

  const FeedRequestScreen({super.key, required this.farmerId});

  @override
  State<FeedRequestScreen> createState() => _FeedRequestScreenState();
}

class _FeedRequestScreenState extends State<FeedRequestScreen> {
  String _selectedFeedType = 'Dairy Meal';
  double _selectedQuantity = 25.0;
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableFeeds = [];
  String _errorMessage = '';

  // Predefined quantity options
  final List<double> _quantityOptions = [25.0, 50.0, 70.0, 100.0, 150.0, 200.0, 300.0, 400.0, 500.0];

  // Feed types that match the React app
  final List<String> _feedTypes = [
    'Dairy Meal',
    'Pollard (Wheat Pollard)',
    'Maize Germ', 
    'Maize Bran',
    'Wheat Bran',
    'Cottonseed Cake',
    'Sunflower Cake',
    'Fish Meal',
    'Soybean Meal',
    'Molasses',
    'Mineral Supplement',
    'Salt',
    'Lucerne Meal',
    'Urea-Molasses Block',
    'Yeast/Probiotic Additives',
    'Protein Concentrate'
  ];

  @override
  void initState() {
    super.initState();
    print('FeedRequestScreen initialized with farmerId: ${widget.farmerId}');
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _fetchAvailableFeeds();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  // Fetch available feeds from inventory
  Future<void> _fetchAvailableFeeds() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('feeds')
          .get();

      print('Fetched ${querySnapshot.docs.length} feeds');
      
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
    } catch (e) {
      print('Error fetching feeds: $e');
      setState(() {
        _errorMessage = 'Error loading feeds: $e';
      });
    }
  }

  // Get stock status for a feed
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

  // Check if requested quantity is available
  bool _isQuantityAvailable(double requestedQuantity) {
    final selectedFeed = _availableFeeds.firstWhere(
      (feed) => feed['type'] == _selectedFeedType,
      orElse: () => {},
    );

    if (selectedFeed.isEmpty) return false;

    final stockStatus = _getStockStatus(selectedFeed);
    final available = stockStatus['available'] ?? 0;
    
    return available >= requestedQuantity;
  }

  // Get available quantity for selected feed
  double _getAvailableQuantity() {
    final selectedFeed = _availableFeeds.firstWhere(
      (feed) => feed['type'] == _selectedFeedType,
      orElse: () => {},
    );

    if (selectedFeed.isEmpty) return 0;

    final stockStatus = _getStockStatus(selectedFeed);
    return (stockStatus['available'] ?? 0).toDouble();
  }

  Future<void> _submitFeedRequest() async {
    if (widget.farmerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Farmer ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if feed type exists in inventory
    final selectedFeed = _availableFeeds.firstWhere(
      (feed) => feed['type'] == _selectedFeedType,
      orElse: () => {},
    );

    if (selectedFeed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_selectedFeedType is not available in inventory'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check stock availability
    if (!_isQuantityAvailable(_selectedQuantity)) {
      final available = _getAvailableQuantity();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient stock! Only $available ${selectedFeed['unit']} available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('Submitting request for farmer: ${widget.farmerId}');
      
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feed request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reset form
      setState(() {
        _selectedFeedType = 'Dairy Meal';
        _selectedQuantity = 25.0;
      });
    } catch (e) {
      print('Error submitting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Feed'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading feed data...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Feed'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Feed'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock Info
            if (_availableFeeds.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📦 Available Stock',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _availableFeeds.take(4).map((feed) {
                          final status = _getStockStatus(feed);
                          return Chip(
                            backgroundColor: _getStockColor(status['class']),
                            label: Text(
                              '${feed['type']}: ${status['available']}${feed['unit']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStockTextColor(status['class']),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Request Form
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Feed Request',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Feed Type
                    const Text('Feed Type', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedFeedType,
                      items: _feedTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedFeedType = value!),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quantity Selection
                    const Text('Quantity (kg)', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _quantityOptions.map((qty) {
                        final isSelected = _selectedQuantity == qty;
                        final isAvailable = _isQuantityAvailable(qty);
                        return ChoiceChip(
                          label: Text('${qty.toInt()} kg'),
                          selected: isSelected,
                          onSelected: isAvailable ? (selected) {
                            if (selected) {
                              setState(() => _selectedQuantity = qty);
                            }
                          } : null,
                          selectedColor: Colors.green,
                          disabledColor: Colors.grey.shade300,
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : 
                                  isAvailable ? Colors.black : Colors.grey,
                          ),
                        );
                      }).toList(),
                    ),

                    if (!_isQuantityAvailable(_selectedQuantity)) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Only ${_getAvailableQuantity()} kg available',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _canSubmit() ? _submitFeedRequest : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'SUBMIT REQUEST', 
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Request History Section
            const Row(
              children: [
                Icon(Icons.history, size: 20),
                SizedBox(width: 8),
                Text(
                  'Request History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // History List
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feed_requests')
          .where('farmerId', isEqualTo: widget.farmerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading history',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your requests will appear here',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return Column(
          children: [
            ...requests.map((doc) {
              final request = doc.data() as Map<String, dynamic>;
              return _buildHistoryCard(request);
            }).toList(),
            const SizedBox(height: 16), // Extra space at bottom
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> request) {
    final feedType = request['feedTypeName'] ?? 'Unknown';
    final quantity = request['quantity'] ?? 0;
    final status = request['status'] ?? 'pending';
    final date = request['createdAt'] != null 
        ? (request['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            
            // Request details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$feedType • ${quantity}kg',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStockColor(String statusClass) {
    switch (statusClass) {
      case 'out-of-stock': return Colors.red.shade100;
      case 'low-stock': return Colors.orange.shade100;
      case 'in-stock': return Colors.green.shade100;
      default: return Colors.grey.shade100;
    }
  }

  Color _getStockTextColor(String statusClass) {
    switch (statusClass) {
      case 'out-of-stock': return Colors.red.shade700;
      case 'low-stock': return Colors.orange.shade700;
      case 'in-stock': return Colors.green.shade700;
      default: return Colors.grey.shade700;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'delivered': return Colors.blue;
      default: return Colors.grey;
    }
  }

  bool _canSubmit() {
    return _isQuantityAvailable(_selectedQuantity);
  }
}