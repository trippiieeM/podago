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
    super.dispose();
  }

  // Load farmers from Firestore
  void _loadFarmers() {
    FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "farmer")
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
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

  // Initialize connectivity monitoring
  void _initializeConnectivity() async {
    // Check initial connectivity
    _isOnline = await ConnectivityService.isConnected();
    
    // Listen for connectivity changes
    _connectivitySubscription = ConnectivityService.connectivityStream.listen(
      (result) async {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        if (!wasOnline && _isOnline) {
          // Just came online - sync pending logs
          _syncPendingLogs();
        }
        
        setState(() {});
      },
    );
  }

  // Check for pending syncs
  Future<void> _checkPendingSyncs() async {
    _pendingSyncCount = await OfflineStorageService.getPendingLogsCount();
    setState(() {});
  }

  // Sync pending logs when back online
  Future<void> _syncPendingLogs() async {
    try {
      final pendingLogs = await OfflineStorageService.getPendingMilkLogs();
      
      if (pendingLogs.isEmpty) return;

      // Show sync indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Syncing $_pendingSyncCount offline logs...'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      int successCount = 0;
      
      for (final log in pendingLogs) {
        try {
          // Ensure farmer name exists with fallback
          final farmerName = log["farmerName"] ?? 'Unknown Farmer';
          
          // Convert offline log to Firestore format
          final firestoreLog = {
            "farmerId": log["farmerId"],
            "farmerName": farmerName,
            "quantity": log["quantity"],
            "notes": log["notes"],
            "status": "pending",
            "date": DateTime.fromMillisecondsSinceEpoch(log["originalTimestamp"]),
            "timestamp": FieldValue.serverTimestamp(),
            "wasOffline": true,
            "syncedAt": FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance.collection("milk_logs").add(firestoreLog);
          await OfflineStorageService.removePendingMilkLog(log);
          successCount++;
        } catch (e) {
          print('Failed to sync log: $e');
        }
      }

      // Update pending count
      await _checkPendingSyncs();

      // Show sync result
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced $successCount logs'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Enhanced milk logging with offline support
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
      // Get farmer name from the dropdown selection
      final farmerName = selectedFarmerName ?? 'Unknown Farmer';
      
      final milkLog = {
        "farmerId": selectedFarmerId,
        "farmerName": farmerName,
        "quantity": double.tryParse(quantityCtrl.text) ?? 0,
        "notes": notesCtrl.text.trim(),
        "originalTimestamp": DateTime.now().millisecondsSinceEpoch,
      };

      if (_isOnline) {
        // Online - save directly to Firestore
        await FirebaseFirestore.instance.collection("milk_logs").add({
          ...milkLog,
          "status": "pending",
          "date": DateTime.now(),
          "timestamp": FieldValue.serverTimestamp(),
          "wasOffline": false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Milk collection logged successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Offline - save locally
        await OfflineStorageService.saveMilkLogOffline(milkLog);
        await _checkPendingSyncs();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Milk saved offline - will sync when online"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }

      // Clear form after successful submission
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

  // View pending offline logs
  void _viewPendingLogs() async {
    final pendingLogs = await OfflineStorageService.getPendingMilkLogs();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Offline Logs'),
        content: pendingLogs.isEmpty 
            ? const Text('No pending offline logs')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pendingLogs.length,
                  itemBuilder: (context, index) {
                    final log = pendingLogs[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(log['originalTimestamp']);
                    final farmerName = log['farmerName'] ?? 'Unknown Farmer';
                    
                    return ListTile(
                      leading: const Icon(Icons.pending, color: Colors.orange),
                      title: Text('${log['quantity']}L - $farmerName'),
                      subtitle: Text(DateFormat('MMM dd, hh:mm a').format(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePendingLog(log),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          if (pendingLogs.isNotEmpty && _isOnline)
            TextButton(
              onPressed: _syncPendingLogs,
              child: const Text('Sync Now'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Delete a pending log
  void _deletePendingLog(Map<String, dynamic> log) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pending Log?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await OfflineStorageService.removePendingMilkLog(log);
      await _checkPendingSyncs();
      if (context.mounted) {
        Navigator.pop(context);
        _viewPendingLogs();
      }
    }
  }

  void _clearForm() {
    quantityCtrl.clear();
    notesCtrl.clear();
    setState(() {
      selectedFarmerId = null;
      selectedFarmerName = null;
      _isSubmitting = false;
    });
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
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(
                child: Text(
                  "Collector Dashboard",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              if (_pendingSyncCount > 0) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_pendingSyncCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: Colors.blue[300],
          elevation: 0,
          actions: [
            if (_pendingSyncCount > 0)
              IconButton(
                icon: Badge(
                  label: Text(
                    '$_pendingSyncCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.cloud_upload, size: 22),
                ),
                tooltip: "View Pending Logs",
                onPressed: _viewPendingLogs,
              ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_rounded, size: 22),
              tooltip: "Register New Farmer",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterFarmerScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 22),
              tooltip: "Logout",
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: _buildBody(isKeyboardVisible),
        bottomNavigationBar: isKeyboardVisible ? null : const BottomNavBar(
          currentIndex: 0,
          role: "collector",
        ),
      ),
    );
  }

  Widget _buildBody(bool isKeyboardVisible) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            flex: isKeyboardVisible ? 7 : 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCollectionForm(),
            ),
          ),
          
          if (!isKeyboardVisible) ...[
            Container(
              height: 1,
              color: Colors.grey[300],
            ),
            
            Expanded(
              flex: 5,
              child: _buildCollectionList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionForm() {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color: _isOnline ? Colors.green[700] : Colors.orange[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? "New Milk Collection" : "Offline Collection",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _isOnline ? Colors.green : Colors.orange,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _isOnline ? "Will save to cloud" : "Will save locally and sync later",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          _buildFarmerDropdown(),
          const SizedBox(height: 12),
          
          TextFormField(
            controller: quantityCtrl,
            decoration: const InputDecoration(
              labelText: "Quantity (Liters)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.scale_rounded),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            keyboardType: TextInputType.number,
            validator: _validateQuantity,
          ),
          const SizedBox(height: 12),
          
          TextFormField(
            controller: notesCtrl,
            decoration: const InputDecoration(
              labelText: "Notes (Optional)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_add_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            maxLines: isKeyboardVisible ? 1 : 2,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
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
              
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _logMilk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnline ? Colors.blue[300] : Colors.orange,
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isOnline ? Icons.cloud_upload : Icons.save,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isOnline ? "Save to Cloud" : "Save Offline",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: selectedFarmerId,
              hint: const Text("Choose farmer"),
              isExpanded: true,
              underline: const SizedBox(), // Remove default underline
              items: _farmersList.map((farmer) {
                return DropdownMenuItem<String>(
                  value: farmer['id'],
                  child: Text(farmer['name']),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  // Find the selected farmer
                  final selectedFarmer = _farmersList.firstWhere(
                    (farmer) => farmer['id'] == newValue,
                    orElse: () => _farmersList.first,
                  );
                  
                  setState(() {
                    selectedFarmerId = newValue;
                    selectedFarmerName = selectedFarmer['name'];
                  });
                }
              },
            ),
          ),
        ),
        
        // Alternative: Show message if no farmers
        if (_farmersList.isEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 40,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                const Text(
                  "No farmers registered yet",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Register a farmer first to log milk collections",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterFarmerScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[300],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Register Farmer"),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCollectionList() {
    return Column(
      children: [
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
              if (_pendingSyncCount > 0 && _isOnline)
                IconButton(
                  icon: Badge(
                    label: Text('$_pendingSyncCount'),
                    child: const Icon(Icons.sync),
                  ),
                  onPressed: _syncPendingLogs,
                  tooltip: "Sync Pending Logs",
                ),
              IconButton(
                icon: const Icon(Icons.logout, size: 18),
                onPressed: () => _logout(context),
                tooltip: "Logout",
              ),
            ],
          ),
        ),
        
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
    final wasOffline = log['wasOffline'] ?? false;
    final farmerName = log['farmerName'] ?? 'Unknown Farmer';
    
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
            color: wasOffline ? Colors.orange[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            wasOffline ? Icons.cloud_done : Icons.local_drink_rounded,
            color: wasOffline ? Colors.orange[700] : Colors.green[700],
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              "${quantity.toStringAsFixed(1)} Liters",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (wasOffline) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.cloud_done,
                size: 16,
                color: Colors.orange[700],
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              farmerName,
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
          if (_pendingSyncCount > 0 && _isOnline)
            ElevatedButton.icon(
              onPressed: _syncPendingLogs,
              icon: const Icon(Icons.sync),
              label: Text('Sync $_pendingSyncCount Pending Logs'),
            ),
          OutlinedButton(
            onPressed: () => _logout(context),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Logout functionality
  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: _pendingSyncCount > 0
            ? Text('You have $_pendingSyncCount unsynced logs. Logout anyway?')
            : const Text('Are you sure you want to logout?'),
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await SimpleStorageService.clearUserSession();
      await FirebaseAuth.instance.signOut();
      
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
}