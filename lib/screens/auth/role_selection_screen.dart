import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:podago/screens/auth/login_screen.dart';
import 'package:podago/services/simple_storage_service.dart';

class RoleSelectionScreen extends StatelessWidget {
  final User? user;
  
  const RoleSelectionScreen({super.key, this.user});

  // --- Professional Theme Colors ---
  static const Color kPrimaryGreen = Color(0xFF1B5E20); // Deep Emerald
  static const Color kAccentBlue = Color(0xFF0277BD);   // Professional Blue
  static const Color kBackground = Color(0xFFF5F7FA);   // Light Grey-Blue
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF757575);

  // ===========================================================================
  // 1. LOGIC SECTION (STRICTLY PRESERVED)
  // ===========================================================================

  Future<void> _selectRole(BuildContext context, String role) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Not logged in yet → Go to Login screen, pass role
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(selectedRole: role),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
    );

    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
        'role': role,
        'email': currentUser.email,
        'lastRoleUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (role == 'farmer') {
        await SimpleStorageService.savePinSession(
          userId: currentUser.uid,
          userName: currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Farmer',
          role: role,
        );
      } else {
        await SimpleStorageService.saveFirebaseSession(
          userId: currentUser.uid,
          userEmail: currentUser.email ?? '',
          role: role,
        );
      }
      
      if (context.mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldLogout == true) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      await SimpleStorageService.clearUserSession();
      await FirebaseAuth.instance.signOut();
      
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 40),

                // Cards
                _buildRoleCard(
                  context,
                  title: "I am a Farmer",
                  subtitle: "Log production & track income",
                  icon: Icons.agriculture,
                  color: kPrimaryGreen,
                  role: "farmer",
                ),
                const SizedBox(height: 20),
                _buildRoleCard(
                  context,
                  title: "I am a Collector",
                  subtitle: "Record collections & manage routes",
                  icon: Icons.local_shipping,
                  color: kAccentBlue,
                  role: "collector",
                ),

                const SizedBox(height: 40),

                // User Info / Footer
                if (user != null)
                  _buildLoggedInFooter(context)
                else
                  const Center(
                    child: Text(
                      "Select a role to sign in or register",
                      style: TextStyle(color: kTextSecondary, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.eco, size: 48, color: kPrimaryGreen),
        ),
        const SizedBox(height: 24),
        const Text(
          "Welcome to Podago",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTextPrimary, letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Streamlining milk collection\nfrom farm to factory.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: kTextSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String role,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectRole(context, role),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInFooter(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 20, color: kTextSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  user?.email ?? "User",
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _logout(context),
          child: const Text("Not you? Switch Account", style: TextStyle(color: kTextSecondary)),
        ),
      ],
    );
  }
}