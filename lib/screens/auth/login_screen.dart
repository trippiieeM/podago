import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:podago/screens/farmer/dashboard_farmer.dart';
import 'package:podago/screens/collector/dashboard_collector.dart';
import 'package:podago/services/simple_storage_service.dart';

class LoginScreen extends StatefulWidget {
  final String? selectedRole;

  const LoginScreen({super.key, this.selectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- Professional Theme Colors ---
  // Farmer Theme
  static const Color kFarmerPrimary = Color(0xFF1B5E20); // Emerald
  static const Color kFarmerAccent = Color(0xFF4CAF50);
  // Collector Theme
  static const Color kCollectorPrimary = Color(0xFF00695C); // Teal
  static const Color kCollectorAccent = Color(0xFF009688);
  
  static const Color kBackground = Color(0xFFF5F7FA); // Defined here as kBackground
  static const Color kCardColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF757575);

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool obscurePin = true;
  bool obscurePassword = true;

  // ===========================================================================
  // 1. LOGIC SECTION
  // ===========================================================================

  /// Farmer login with name + PIN
  Future<void> _loginFarmer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "farmer")
          .where("name", isEqualTo: _nameController.text.trim())
          .where("pin", isEqualTo: _pinController.text.trim())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final farmerDoc = query.docs.first;
        await SimpleStorageService.savePinSession(
          userId: farmerDoc.id,
          userName: _nameController.text.trim(),
          role: 'farmer',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Login successful!"), backgroundColor: Colors.green[700]));
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FarmerDashboard(farmerId: farmerDoc.id)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid name or PIN"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login error: ${e.toString()}"), backgroundColor: Colors.red));
    }

    if (mounted) setState(() => isLoading = false);
  }

  /// Collector login with email + password
  Future<void> _loginCollector() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    
    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCred.user;
      if (user == null) throw Exception("Login failed");

      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      final role = doc["role"];
      
      if (role == "collector") {
        await SimpleStorageService.saveFirebaseSession(
          userId: user.uid,
          userEmail: user.email ?? '',
          role: 'collector',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Login successful!"), backgroundColor: Colors.green[700]));
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CollectorDashboard()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not authorized as Collector"), backgroundColor: Colors.orange));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed"), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login error: ${e.toString()}"), backgroundColor: Colors.red));
    }
    
    if (mounted) setState(() => isLoading = false);
  }

  String? _validateName(String? value) => (value == null || value.isEmpty) ? 'Please enter your name' : null;
  String? _validatePIN(String? value) => (value == null || value.length < 4) ? 'PIN must be 4 digits' : null;
  String? _validateEmail(String? value) => (value == null || !value.contains('@')) ? 'Invalid email' : null;
  String? _validatePassword(String? value) => (value == null || value.length < 6) ? 'Password too short' : null;

  void _togglePinVisibility() => setState(() => obscurePin = !obscurePin);
  void _togglePasswordVisibility() => setState(() => obscurePassword = !obscurePassword);

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 2. UI SECTION
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isFarmer = widget.selectedRole == "farmer";
    final primaryColor = isFarmer ? kFarmerPrimary : kCollectorPrimary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: kTextPrimary),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Header
                  _buildHeader(isFarmer, primaryColor),
                  const SizedBox(height: 40),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (isFarmer) ...[
                            _buildInputField(_nameController, "Full Name", Icons.person_outline, validator: _validateName),
                            const SizedBox(height: 20),
                            _buildInputField(
                              _pinController, 
                              "4-Digit PIN", 
                              Icons.lock_outline, 
                              isPassword: true, 
                              isPin: true,
                              validator: _validatePIN
                            ),
                          ] else ...[
                            _buildInputField(_emailController, "Email Address", Icons.email_outlined, validator: _validateEmail),
                            const SizedBox(height: 20),
                            _buildInputField(
                              _passwordController, 
                              "Password", 
                              Icons.lock_outline, 
                              isPassword: true, 
                              validator: _validatePassword
                            ),
                          ],
                          
                          const SizedBox(height: 32),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : (isFarmer ? _loginFarmer : _loginCollector),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Help Text
                  Text(
                    isFarmer ? "Forgot PIN? Ask your collector." : "Forgot password? Contact admin.",
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isFarmer, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFarmer ? Icons.agriculture : Icons.local_shipping,
            size: 40,
            color: color,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Welcome Back",
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          isFarmer ? "Access your farm dashboard" : "Manage your collection route",
          style: const TextStyle(fontSize: 16, color: kTextSecondary),
        ),
      ],
    );
  }

  Widget _buildInputField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {bool isPassword = false, 
    bool isPin = false,
    String? Function(String?)? validator}
  ) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && (isPin ? obscurePin : obscurePassword),
      keyboardType: isPin ? TextInputType.number : TextInputType.text,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500, color: kTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kTextSecondary),
        prefixIcon: Icon(icon, color: kTextSecondary),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(
                (isPin ? obscurePin : obscurePassword) ? Icons.visibility_off : Icons.visibility, 
                color: kTextSecondary
              ),
              onPressed: isPin ? _togglePinVisibility : _togglePasswordVisibility,
            ) 
          : null,
        filled: true,
        // ✅ CORRECTED: Used kBackground instead of kBackgroundColor
        fillColor: kBackground, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isPassword ? kTextSecondary : kFarmerPrimary, width: 1.5)),
      ),
    );
  }
}