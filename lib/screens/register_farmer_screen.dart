import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class RegisterFarmerScreen extends StatefulWidget {
  const RegisterFarmerScreen({super.key});

  @override
  State<RegisterFarmerScreen> createState() => _RegisterFarmerScreenState();
}

class _RegisterFarmerScreenState extends State<RegisterFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController pinCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  bool isLoading = false;
  bool obscurePin = true;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final connected = connectivityResult != ConnectivityResult.none;
      setState(() => isOnline = connected);
    } catch (e) {
      setState(() => isOnline = false);
    }
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      final connected = result != ConnectivityResult.none;
      if (mounted) {
        setState(() => isOnline = connected);
      }
      
      // Auto-sync when coming back online
      if (connected) {
        _syncOfflineFarmers();
      }
    });
  }

  Future<void> _registerFarmer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final farmerData = {
        "name": nameCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
        "pin": pinCtrl.text.trim(),
        "location": locationCtrl.text.trim(),
        "role": "farmer",
        "collectorId": currentUser?.uid,
        "collectorName": currentUser?.displayName ?? "Unknown Collector",
        "createdBy": currentUser?.uid,
        "createdAt": DateTime.now().toIso8601String(),
        "updatedAt": DateTime.now().toIso8601String(),
        "status": "active",
        "synced": isOnline,
        "offlineTimestamp": DateTime.now().millisecondsSinceEpoch,
        "isOffline": !isOnline,
      };

      if (isOnline) {
        await _registerOnline(farmerData);
      } else {
        await _registerOffline(farmerData);
      }

    } catch (e) {
      _showErrorSnackBar("Registration failed: ${e.toString()}");
      setState(() => isLoading = false);
    }
  }

  Future<void> _registerOnline(Map<String, dynamic> farmerData) async {
    try {
      // Check if farmer with same phone already exists
      final existingFarmers = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", isEqualTo: farmerData["phone"])
          .where("role", isEqualTo: "farmer")
          .get();

      if (existingFarmers.docs.isNotEmpty) {
        _showWarningSnackBar("Farmer with this phone number already exists");
        setState(() => isLoading = false);
        return;
      }

      // Remove offline fields before saving to Firestore
      final onlineData = Map<String, dynamic>.from(farmerData);
      onlineData.remove('offlineTimestamp');
      onlineData.remove('isOffline');
      onlineData['synced'] = true;

      await FirebaseFirestore.instance.collection("users").add(onlineData);
      _showSuccessSnackBar("Farmer registered successfully!");
      _clearFormAndNavigate();
    } catch (e) {
      // If online registration fails, fall back to offline
      print("Online registration failed, falling back to offline: $e");
      await _registerOffline(farmerData);
    }
  }

  Future<void> _registerOffline(Map<String, dynamic> farmerData) async {
    try {
      await _saveFarmerOffline(farmerData);
      _showSuccessSnackBar("Farmer registered offline! Data will sync when online.");
      _clearFormAndNavigate();
    } catch (e) {
      _showErrorSnackBar("Offline registration failed: ${e.toString()}");
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveFarmerOffline(Map<String, dynamic> farmerData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing offline farmers
    final offlineFarmersJson = prefs.getStringList('offline_farmers') ?? [];
    final List<Map<String, dynamic>> offlineFarmers = [];

    for (final json in offlineFarmersJson) {
      try {
        offlineFarmers.add(jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        // Skip invalid JSON entries
        continue;
      }
    }

    // Check for duplicates in offline data
    final duplicate = offlineFarmers.any((farmer) => 
        farmer["phone"] == farmerData["phone"] && farmer["role"] == "farmer");
    
    if (duplicate) {
      throw Exception("Farmer with this phone number already exists in offline data");
    }

    // Add to offline storage
    offlineFarmers.add(farmerData);
    final updatedJsonList = offlineFarmers.map((farmer) => jsonEncode(farmer)).toList();
    await prefs.setStringList('offline_farmers', updatedJsonList);
  }

  Future<void> _syncOfflineFarmers() async {
    if (isLoading) return;
    
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineFarmersJson = prefs.getStringList('offline_farmers') ?? [];
      
      if (offlineFarmersJson.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      int syncedCount = 0;
      final List<String> remainingFarmers = [];

      for (final farmerJson in offlineFarmersJson) {
        try {
          final farmerData = jsonDecode(farmerJson) as Map<String, dynamic>;
          
          // Skip if already synced
          if (farmerData["synced"] == true) {
            continue;
          }

          // Check if farmer already exists online
          final existingFarmers = await FirebaseFirestore.instance
              .collection("users")
              .where("phone", isEqualTo: farmerData["phone"])
              .where("role", isEqualTo: "farmer")
              .get();

          if (existingFarmers.docs.isEmpty) {
            // Prepare data for Firestore
            final onlineData = Map<String, dynamic>.from(farmerData);
            onlineData.remove('offlineTimestamp');
            onlineData.remove('isOffline');
            onlineData['synced'] = true;
            onlineData['updatedAt'] = DateTime.now().toIso8601String();
            
            await FirebaseFirestore.instance.collection("users").add(onlineData);
            syncedCount++;
          } else {
            // Farmer already exists, keep in list to remove
            print("Farmer with phone ${farmerData["phone"]} already exists online");
          }
          
        } catch (e) {
          // If sync fails for this farmer, keep it in offline storage
          print("Failed to sync farmer: $e");
          remainingFarmers.add(farmerJson);
        }
      }

      // Update local storage - keep only failed sync attempts
      await prefs.setStringList('offline_farmers', remainingFarmers);

      if (syncedCount > 0) {
        _showSuccessSnackBar("$syncedCount offline farmers synced successfully!");
      }
      
    } catch (e) {
      print("Sync failed: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<int> _getOfflineFarmersCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineFarmersJson = prefs.getStringList('offline_farmers') ?? [];
      return offlineFarmersJson.length;
    } catch (e) {
      return 0;
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearFormAndNavigate() {
    _formKey.currentState?.reset();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => isLoading = false);
        Navigator.pop(context);
      }
    });
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validatePIN(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please set a PIN';
    }
    if (value.length < 4) {
      return 'PIN must be at least 4 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN must contain only numbers';
    }
    return null;
  }

  void _togglePinVisibility() {
    setState(() {
      obscurePin = !obscurePin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Register New Farmer",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: isOnline ? Colors.blue[400] : Colors.orange[400],
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!isOnline)
              FutureBuilder<int>(
                future: _getOfflineFarmersCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count > 0) {
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.sync_rounded),
                          tooltip: "Sync Offline Farmers",
                          onPressed: isLoading ? null : _syncOfflineFarmers,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: "Sync Offline Farmers",
                      onPressed: isLoading ? null : _syncOfflineFarmers,
                    );
                  }
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Section
              _buildHeaderSection(),
              const SizedBox(height: 24),

              // Connectivity Status
              _buildConnectivityStatus(),
              const SizedBox(height: 24),

              // Registration Form
              _buildRegistrationForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green[50] : Colors.orange[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOnline ? Icons.person_add_alt_1_rounded : Icons.save_alt_rounded,
            color: isOnline ? Colors.green[700] : Colors.orange[700],
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Register New Farmer",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isOnline ? Colors.green[800] : Colors.orange[800],
              ),
        ),
        const SizedBox(height: 8),
        Text(
          isOnline 
            ? "Add a new farmer to your collection network"
            : "Offline Mode - Farmer data saved locally",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildConnectivityStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnline ? Colors.green[100]! : Colors.orange[100]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: isOnline ? Colors.green[600] : Colors.orange[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "Online Mode" : "Offline Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isOnline ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
                Text(
                  isOnline 
                    ? "Farmers will be saved directly to cloud"
                    : "Farmers saved locally. Auto-sync when online.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
          if (!isOnline)
            FutureBuilder<int>(
              future: _getOfflineFarmersCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return TextButton(
                  onPressed: isLoading ? null : _syncOfflineFarmers,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                  ),
                  child: Text(
                    "SYNC${count > 0 ? ' ($count)' : ''}",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: "Farmer Full Name *",
              hintText: "Enter farmer's full name",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value == null || value.isEmpty ? "Please enter farmer name" : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: phoneCtrl,
            decoration: const InputDecoration(
              labelText: "Phone Number *",
              hintText: "Enter 10-digit phone number",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: locationCtrl,
            decoration: const InputDecoration(
              labelText: "Location",
              hintText: "Enter farmer's location or village",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: pinCtrl,
            obscureText: obscurePin,
            decoration: InputDecoration(
              labelText: "Login PIN *",
              hintText: "Set 4-digit PIN for farmer login",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey[600],
                ),
                onPressed: _togglePinVisibility,
              ),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: _validatePIN,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  "Farmer will use this PIN to log into their account",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _registerFarmer,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(isOnline ? Icons.person_add_alt_rounded : Icons.save_alt_rounded),
            label: Text(
              isLoading ? "Processing..." : "Register Farmer",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOnline ? Colors.blue[400] : Colors.orange[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    pinCtrl.dispose();
    locationCtrl.dispose();
    super.dispose();
  }
}