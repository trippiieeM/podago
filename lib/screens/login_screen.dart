import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_farmer.dart';
import 'dashboard_collector.dart';

class LoginScreen extends StatefulWidget {
  final String?
  selectedRole; // "farmer" or "collector" from RoleSelectionScreen

  const LoginScreen({super.key, this.selectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLoading = false;

  /// Farmer login with name + PIN
  Future<void> _loginFarmer() async {
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FarmerDashboard(farmerId: farmerDoc.id),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid name or PIN")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => isLoading = false);
  }

  /// Collector login with email + password (FirebaseAuth)
  Future<void> _loginCollector() async {
    setState(() => isLoading = true);
    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCred.user;
      if (user == null) throw Exception("Login failed");

      // Fetch role from Firestore
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final role = doc["role"];
      if (role == "collector") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CollectorDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Not authorized as Collector")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isFarmer = widget.selectedRole == "farmer";

    return Scaffold(
      appBar: AppBar(
        title: Text(isFarmer ? "Farmer Login" : "Collector Login"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (isFarmer) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Farmer Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "PIN (set by Collector)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ] else ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: isFarmer ? _loginFarmer : _loginCollector,
                    child: Text(
                      isFarmer ? "Login as Farmer" : "Login as Collector",
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
