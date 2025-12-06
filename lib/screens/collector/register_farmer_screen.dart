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
  // --- Professional Theme Colors ---
  static const Color kPrimaryColor = Color(0xFF00695C); // Teal 800
  static const Color kAccentColor = Color(0xFF009688);  // Teal 500
  static const Color kBackgroundColor = Color(0xFFF5F7FA);
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF263238);
  static const Color kTextSecondary = Color(0xFF78909C);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController pinCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  bool isLoading = false;
  bool obscurePin = true;
  bool isOnline = true;

  // ===========================================================================
  // 1. LOGIC SECTION (STRICTLY PRESERVED)
  // ===========================================================================

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

      final onlineData = Map<String, dynamic>.from(farmerData);
      onlineData.remove('offlineTimestamp');
      onlineData.remove('isOffline');
      onlineData['synced'] = true;

      await FirebaseFirestore.instance.collection("users").add(onlineData);
      _showSuccessSnackBar("Farmer registered successfully!");
      _clearFormAndNavigate();
    } catch (e) {
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
    final offlineFarmersJson = prefs.getStringList('offline_farmers') ?? [];
    final List<Map<String, dynamic>> offlineFarmers = [];

    for (final json in offlineFarmersJson) {
      try {
        offlineFarmers.add(jsonDecode(json) as Map<String, dynamic>);
      } catch (e) { continue; }
    }

    final duplicate = offlineFarmers.any((farmer) => 
        farmer["phone"] == farmerData["phone"] && farmer["role"] == "farmer");
    
    if (duplicate) {
      throw Exception("Farmer with this phone number already exists in offline data");
    }

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
          if (farmerData["synced"] == true) continue;

          final existingFarmers = await FirebaseFirestore.instance
              .collection("users")
              .where("phone", isEqualTo: farmerData["phone"])
              .where("role", isEqualTo: "farmer")
              .get();

          if (existingFarmers.docs.isEmpty) {
            final onlineData = Map<String, dynamic>.from(farmerData);
            onlineData.remove('offlineTimestamp');
            onlineData.remove('isOffline');
            onlineData['synced'] = true;
            onlineData['updatedAt'] = DateTime.now().toIso8601String();
            
            await FirebaseFirestore.instance.collection("users").add(onlineData);
            syncedCount++;
          }
        } catch (e) {
          remainingFarmers.add(farmerJson);
        }
      }

      await prefs.setStringList('offline_farmers', remainingFarmers);
      if (syncedCount > 0) _showSuccessSnackBar("$syncedCount offline farmers synced successfully!");
      
    } catch (e) {
      print("Sync failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<int> _getOfflineFarmersCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineFarmersJson = prefs.getStringList('offline_farmers') ?? [];
      return offlineFarmersJson.length;
    } catch (e) { return 0; }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: kPrimaryColor, behavior: SnackBarBehavior.floating));
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange[700], behavior: SnackBarBehavior.floating));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
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
    if (value == null || value.isEmpty) return 'Please enter phone number';
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value)) return 'Please enter a valid phone number';
    return null;
  }

  String? _validatePIN(String? value) {
    if (value == null || value.isEmpty) return 'Please set a PIN';
    if (value.length < 4) return 'PIN must be at least 4 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'PIN must contain only numbers';
    return null;
  }

  void _togglePinVisibility() {
    setState(() => obscurePin = !obscurePin);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    pinCtrl.dispose();
    locationCtrl.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 2. UI SECTION (PROFESSIONAL REDESIGN)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: const Text("Register Farmer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          actions: [
            if (!isOnline)
              FutureBuilder<int>(
                future: _getOfflineFarmersCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.sync, color: Colors.white),
                        tooltip: "Sync Offline",
                        onPressed: isLoading ? null : _syncOfflineFarmers,
                      ),
                      if (count > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectivityStatus(),
              const SizedBox(height: 20),
              _buildRegistrationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectivityStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOnline ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isOnline ? Icons.wifi : Icons.wifi_off, color: isOnline ? kPrimaryColor : Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "Online Mode" : "Offline Mode",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isOnline ? kPrimaryColor : Colors.orange.shade900),
                ),
                Text(
                  isOnline ? "Data saves directly to cloud" : "Data saves locally. Auto-sync when online.",
                  style: TextStyle(fontSize: 12, color: isOnline ? kPrimaryColor.withOpacity(0.7) : Colors.orange.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Farmer Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
            const SizedBox(height: 20),
            
            _buildInputField(nameCtrl, "Full Name", Icons.person_outline, validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            
            _buildInputField(phoneCtrl, "Phone Number", Icons.phone_outlined, keyboardType: TextInputType.phone, validator: _validatePhone),
            const SizedBox(height: 16),
            
            _buildInputField(locationCtrl, "Location / Village", Icons.location_on_outlined),
            const SizedBox(height: 16),
            
            _buildInputField(
              pinCtrl, 
              "Login PIN", 
              Icons.lock_outline, 
              isPassword: true, 
              keyboardType: TextInputType.number, 
              validator: _validatePIN,
              helperText: "4-digit PIN for farmer login"
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _registerFarmer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? kPrimaryColor : Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isOnline ? Icons.check_circle_outline : Icons.save_alt, size: 20),
                        const SizedBox(width: 8),
                        Text(isOnline ? "Register Farmer" : "Save Offline", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {bool isPassword = false, 
    TextInputType? keyboardType, 
    String? Function(String?)? validator,
    String? helperText}
  ) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && obscurePin,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500, color: kTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kTextSecondary),
        helperText: helperText,
        prefixIcon: Icon(icon, color: kTextSecondary),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, color: kTextSecondary),
              onPressed: _togglePinVisibility,
            ) 
          : null,
        filled: true,
        fillColor: kBackgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2)),
      ),
    );
  }
}