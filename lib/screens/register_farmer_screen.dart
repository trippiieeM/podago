import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  bool isLoading = false;
  bool obscurePin = true;

  Future<void> _registerFarmer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Check if farmer with same phone already exists
      final existingFarmers = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", isEqualTo: phoneCtrl.text.trim())
          .where("role", isEqualTo: "farmer")
          .get();

      if (existingFarmers.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Farmer with this phone number already exists"),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection("users").add({
        "name": nameCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
        "pin": pinCtrl.text.trim(),
        "location": locationCtrl.text.trim(),
        "role": "farmer",
        "collectorId": currentUser?.uid,
        "collectorName": currentUser?.displayName ?? "Unknown Collector",
        "createdBy": currentUser?.uid,
        "createdAt": DateTime.now(),
        "updatedAt": DateTime.now(),
        "status": "active",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Farmer registered successfully!"),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // Clear form and navigate back after success
      _formKey.currentState!.reset();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registration failed: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }
    // Basic phone validation - adjust based on your country
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
          backgroundColor: Colors.blue[400],
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Section
              _buildHeaderSection(),
              const SizedBox(height: 32),

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
            color: Colors.green[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.green[700],
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Register New Farmer",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Add a new farmer to your collection network",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Farmer Name
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
          const SizedBox(height: 20),

          // Phone Number
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
          const SizedBox(height: 20),

          // Location
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
          const SizedBox(height: 20),

          // PIN
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

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Register Button
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
                : const Icon(Icons.person_add_alt_rounded),
            label: Text(
              isLoading ? "Registering..." : "Register Farmer",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cancel Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () {
                    _formKey.currentState?.reset();
                    Navigator.pop(context);
                  },
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