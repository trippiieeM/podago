import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/dashboard_farmer.dart';
import 'screens/dashboard_collector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(const PodagoApp());
}

class PodagoApp extends StatelessWidget {
  const PodagoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Podago',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getStartScreen() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1️⃣ No user → show role selection FIRST
    if (user == null) {
      return const RoleSelectionScreen();
    }

    // 2️⃣ If user exists → check Firestore for their role
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists || !doc.data()!.containsKey('role')) {
      // In case role is missing, ask again
      return const RoleSelectionScreen();
    }

    final role = doc['role'];

    if (role == 'farmer') {
      return FarmerDashboard(farmerId: user.uid);
    } else if (role == 'collector') {
      return const CollectorDashboard();
    }

    return const RoleSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const RoleSelectionScreen();
      },
    );
  }
}
