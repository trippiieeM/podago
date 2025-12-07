import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'package:podago/widgets/bottom_nav_bar.dart';
import 'package:podago/screens/collector/register_farmer_screen.dart';
import 'package:podago/services/simple_storage_service.dart';
import 'package:podago/screens/auth/role_selection_screen.dart';
import 'package:podago/services/offline_storage_service.dart';
import 'package:podago/services/connectivity_service.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  // --- Professional Theme Colors ---
  static const Color kPrimaryColor = Color(0xFF00695C); // Teal 800
  static const Color kAccentColor = Color(0xFF009688);  // Teal 500
  static const Color kBackgroundColor = Color(0xFFF5F7FA);
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF263238);
  static const Color kTextSecondary = Color(0xFF78909C);
  
  // --- State Variables (Preserved) ---
  String? selectedFarmerId;
  String? selectedFarmerName;
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isOnline = true;
  int _pendingSyncCount = 0;
  StreamSubscription? _connectivitySubscription;
  List<Map<String, dynamic>> _farmersList = [];

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _checkPendingSyncs();
    _loadFarmers();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    quantityCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  void _loadFarmers() {
    FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "farmer")
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _farmersList = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown Farmer',
              'data': data,
            };
          }).toList();
        });
      }
    });
  }

  void _initializeConnectivity() async {
    _isOnline = await ConnectivityService.isConnected();
    _connectivitySubscription = ConnectivityService.connectivityStream.listen(
      (result) async {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        if (!wasOnline && _isOnline) {
          _syncPendingLogs();
        }
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _checkPendingSyncs() async {
    _pendingSyncCount = await OfflineStorageService.getPendingLogsCount();
    if (mounted) setState(() {});
  }

  Future<void> _syncPendingLogs() async {
    try {
      final pendingLogs = await OfflineStorageService.getPendingMilkLogs();
      if (pendingLogs.isEmpty) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Syncing $_pendingSyncCount logs...'), backgroundColor: Colors.blue));
      }

      int successCount = 0;
      for (final log in pendingLogs) {
        try {
          final farmerName = log["farmerName"] ?? 'Unknown Farmer';
          await FirebaseFirestore.instance.collection("milk_logs").add({
            "farmerId": log["farmerId"],
            "farmerName": farmerName,
            "quantity": log["quantity"],
            "notes": log["notes"],
            "status": "pending",
            "date": DateTime.fromMillisecondsSinceEpoch(log["originalTimestamp"]),
            "timestamp": FieldValue.serverTimestamp(),
            "wasOffline": true,
            "syncedAt": FieldValue.serverTimestamp(),
          });
          await OfflineStorageService.removePendingMilkLog(log);
          successCount++;
        } catch (e) {
          print('Failed to sync log: $e');
        }
      }
      await _checkPendingSyncs();
      if (successCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synced $successCount logs'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _logMilk() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a farmer first"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final farmerName = selectedFarmerName ?? 'Unknown Farmer';
      final milkLog = {
        "farmerId": selectedFarmerId,
        "farmerName": farmerName,
        "quantity": double.tryParse(quantityCtrl.text) ?? 0,
        "notes": notesCtrl.text.trim(),
        "originalTimestamp": DateTime.now().millisecondsSinceEpoch,
      };

      if (_isOnline) {
        await FirebaseFirestore.instance.collection("milk_logs").add({
          ...milkLog,
          "status": "pending",
          "date": DateTime.now(),
          "timestamp": FieldValue.serverTimestamp(),
          "wasOffline": false,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to Cloud"), backgroundColor: Colors.green));
      } else {
        await OfflineStorageService.saveMilkLogOffline(milkLog);
        await _checkPendingSyncs();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Offline"), backgroundColor: Colors.orange));
      }
      _clearForm();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    quantityCtrl.clear();
    notesCtrl.clear();
    if (mounted) {
      setState(() {
        selectedFarmerId = null;
        selectedFarmerName = null;
        _isSubmitting = false;
      });
    }
    _formKey.currentState?.reset();
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final quantity = double.tryParse(value);
    if (quantity == null || quantity <= 0) return 'Invalid';
    if (quantity > 1000) return 'Too high';
    return null;
  }

  Future<void> _logout(BuildContext context) async {
    // Keep original logout logic
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: _pendingSyncCount > 0 ? Text('Warning: $_pendingSyncCount unsynced logs.') : const Text('Logout now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldLogout == true) {
      await SimpleStorageService.clearUserSession();
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (route) => false);
      }
    }
  }

  void _viewPendingLogs() async {
    // Keep original pending logs view logic
    final pendingLogs = await OfflineStorageService.getPendingMilkLogs();
    if(!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Logs'),
        content: pendingLogs.isEmpty ? const Text("No logs") : SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: pendingLogs.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final log = pendingLogs[index];
              return ListTile(
                title: Text(log['farmerName']),
                subtitle: Text("${log['quantity']}L"),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                   await OfflineStorageService.removePendingMilkLog(log);
                   await _checkPendingSyncs();
                   Navigator.pop(context); 
                }),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: _buildAppBar(),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Status Bar (Fixed Height)
              _buildStatusBar(),
              
              // 2. Main Content (Scrollable Form + List)
              Expanded(
                child: Column(
                  children: [
                    // Form Section (Scrollable for small screens)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildCollectionForm(),
                    ),
                    
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),

                    // List Section (Takes remaining space)
                    Expanded(
                      child: _buildCollectionList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Hide nav bar when keyboard is open to avoid overflow
        bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom == 0 
            ? const BottomNavBar(currentIndex: 0, role: "collector") 
            : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Collector Dashboard",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
      ),
      backgroundColor: kPrimaryColor,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          tooltip: "Register Farmer",
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterFarmerScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: "Logout",
          onPressed: () => _logout(context),
        ),
      ],
    );
  }

  // Dedicated Status Bar for Network & Sync
  Widget _buildStatusBar() {
    final bgColor = _isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0); // Light Green vs Light Orange
    final textColor = _isOnline ? Colors.green[800] : Colors.orange[900];
    final iconColor = _isOnline ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: iconColor),
          const SizedBox(width: 8),
          Text(
            _isOnline ? "Online Mode" : "Offline Mode",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const Spacer(),
          if (_pendingSyncCount > 0)
            InkWell(
              onTap: _viewPendingLogs,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      "$_pendingSyncCount Pending",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionForm() {
    return Card(
      elevation: 0, // Flat design with border
      color: kCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("New Collection", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 20),
              
              _buildFarmerDropdown(),
              const SizedBox(height: 16),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildInputField(
                      controller: quantityCtrl,
                      label: "Quantity",
                      hint: "0.0",
                      suffix: "L",
                      icon: Icons.scale_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _validateQuantity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: _buildInputField(
                      controller: notesCtrl,
                      label: "Notes",
                      hint: "Optional",
                      icon: Icons.edit_note,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextSecondary,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Clear"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _logMilk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline ? kPrimaryColor : Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isOnline ? Icons.save_alt : Icons.save, size: 20),
                      label: Text(_isSubmitting ? "Saving..." : (_isOnline ? "Submit Log" : "Save Offline")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            prefixIcon: Icon(icon, size: 20, color: kTextSecondary),
            filled: true,
            fillColor: kBackgroundColor,
            // High padding ensures text is vertically centered and easy to tap
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildFarmerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Farmer", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedFarmerId,
              hint: const Text("Choose from list", style: TextStyle(fontSize: 14, color: Colors.grey)),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: kTextSecondary),
              items: _farmersList.map((farmer) {
                return DropdownMenuItem<String>(
                  value: farmer['id'],
                  child: Text(farmer['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  final selectedFarmer = _farmersList.firstWhere((farmer) => farmer['id'] == newValue);
                  setState(() {
                    selectedFarmerId = newValue;
                    selectedFarmerName = selectedFarmer['name'];
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Records", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextSecondary)),
              if (_pendingSyncCount > 0 && _isOnline)
                TextButton(
                  onPressed: _syncPendingLogs,
                  child: const Text("Sync All Now", style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("milk_logs")
                .where("date", isGreaterThanOrEqualTo: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                .orderBy("date", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

              final logs = snapshot.data!.docs;
              
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  return _buildCollectionItem(log);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> log) {
    final timestamp = (log['date'] as Timestamp).toDate();
    final quantity = log['quantity'] ?? 0;
    final wasOffline = log['wasOffline'] ?? false;
    final farmerName = log['farmerName'] ?? 'Unknown';
    
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: wasOffline ? Colors.orange.shade50 : Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.water_drop,
            color: wasOffline ? Colors.orange : Colors.green,
            size: 20,
          ),
        ),
        title: Text(farmerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary)),
        subtitle: Row(
          children: [
            if (wasOffline) ...[
              const Icon(Icons.cloud_off, size: 12, color: Colors.orange),
              const SizedBox(width: 4),
            ],
            Text(DateFormat('hh:mm a').format(timestamp), style: const TextStyle(fontSize: 12, color: kTextSecondary)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            "${quantity.toStringAsFixed(1)} L",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("No records today", style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}