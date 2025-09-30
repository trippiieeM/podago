import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
import 'register_farmer_screen.dart';
import '../services/simple_storage_service.dart';
import 'role_selection_screen.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  String? selectedFarmerId;
  String? selectedFarmerName;
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Logout functionality
  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Clear local storage
      await SimpleStorageService.clearUserSession();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Close loading and navigate
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _logMilk() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a farmer"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection("milk_logs").add({
        "farmerId": selectedFarmerId,
        "farmerName": selectedFarmerName,
        "quantity": double.tryParse(quantityCtrl.text) ?? 0,
        "notes": notesCtrl.text.trim(),
        "status": "pending",
        "date": DateTime.now(),
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Milk collection logged successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Clear all form fields after successful submission
      _clearForm();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving milk log: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    // Clear text controllers
    quantityCtrl.clear();
    notesCtrl.clear();
    
    // Reset dropdown selection
    setState(() {
      selectedFarmerId = null;
      selectedFarmerName = null;
      _isSubmitting = false;
    });
    
    // Reset form validation state
    _formKey.currentState?.reset();
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter quantity';
    }
    final quantity = double.tryParse(value);
    if (quantity == null || quantity <= 0) {
      return 'Please enter a valid quantity';
    }
    if (quantity > 1000) {
      return 'Quantity seems unusually high';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Collector Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[300],
        elevation: 0,
        actions: [
          // Register Farmer Button
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded),
            tooltip: "Register New Farmer",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterFarmerScreen()),
              );
            },
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Form Section - Fixed height that works
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCollectionForm(),
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
          
          // List Section - Takes remaining space
          Expanded(
            child: _buildCollectionList(),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 0,
        role: "collector",
      ),
    );
  }

  Widget _buildCollectionForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.green[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "New Milk Collection",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Farmer Selection
          _buildFarmerDropdown(),
          const SizedBox(height: 16),
          
          // Quantity Input
          TextFormField(
            controller: quantityCtrl,
            decoration: const InputDecoration(
              labelText: "Quantity (Liters)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.scale_rounded),
            ),
            keyboardType: TextInputType.number,
            validator: _validateQuantity,
          ),
          const SizedBox(height: 16),
          
          // Notes Input
          TextFormField(
            controller: notesCtrl,
            decoration: const InputDecoration(
              labelText: "Notes (Optional)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_add_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              // Clear Button
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _clearForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Clear"),
                ),
              ),
              const SizedBox(width: 12),
              
              // Submit Button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _logMilk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          "Save Collection",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFarmerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Select Farmer",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .where("role", isEqualTo: "farmer")
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    "Error loading farmers",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            final farmers = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              value: selectedFarmerId,
              hint: const Text("Choose farmer"),
              items: farmers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Unnamed Farmer';
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(name),
                  onTap: () {
                    selectedFarmerName = name;
                  },
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedFarmerId = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCollectionList() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.today_rounded,
                  color: Colors.green[700],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Collections",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Recent milk collections",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Quick logout option in the header
              IconButton(
                icon: Icon(
                  Icons.logout,
                  size: 18,
                  color: Colors.grey[600],
                ),
                onPressed: () => _logout(context),
                tooltip: "Logout",
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("milk_logs")
                .where(
                  "date",
                  isGreaterThanOrEqualTo: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
                )
                .orderBy("date", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final logs = snapshot.data!.docs;
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  return _buildCollectionItem(log, index);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> log, int index) {
    final timestamp = (log['date'] as Timestamp).toDate();
    final quantity = log['quantity'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.local_drink_rounded,
            color: Colors.green[700],
            size: 20,
          ),
        ),
        title: Text(
          "${quantity.toStringAsFixed(1)} Liters",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log['farmerName'] ?? 'Unknown Farmer',
              style: const TextStyle(fontSize: 14),
            ),
            if (log['notes'] != null && log['notes'].isNotEmpty)
              Text(
                log['notes'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('hh:mm a').format(timestamp),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            Text(
              DateFormat('MMM dd').format(timestamp),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            "No Collections Today",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Milk collections will appear here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          // Add logout option in empty state too
          OutlinedButton(
            onPressed: () => _logout(context),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    quantityCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }
}