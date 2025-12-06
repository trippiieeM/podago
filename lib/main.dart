import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:podago/screens/auth/login_screen.dart';
import 'package:podago/screens/auth/role_selection_screen.dart';
import 'package:podago/screens/farmer/dashboard_farmer.dart';
import 'package:podago/screens/collector/dashboard_collector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:podago/services/simple_storage_service.dart';

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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Widget> _checkLocalSession() async {
    print('🕵️ Checking local session...');
    final localSession = await SimpleStorageService.getUserSession();
    
    print('📱 Local storage data: $localSession');

    // If we have local session data, use it immediately
    if (localSession != null && await SimpleStorageService.hasValidSession()) {
      final role = localSession['role'];
      final userId = localSession['userId'];
      final authType = localSession['authType'];
      
      print('🎯 Found valid local session: $role for user: $userId (Auth: $authType)');
      
      if (authType == 'pin') {
        // PIN-based session (Farmer) - no Firebase Auth check needed
        print('🔐 PIN-based session - redirecting to FarmerDashboard');
        return FarmerDashboard(farmerId: userId);
      } else {
        // Firebase Auth session (Collector) - verify with Firebase
        final firebaseUser = FirebaseAuth.instance.currentUser;
        print('🔥 Firebase current user: $firebaseUser');
        
        if (firebaseUser != null && firebaseUser.uid == userId) {
          print('✅ Firebase session verified');
          if (role == 'collector') {
            return const CollectorDashboard();
          } else if (role == 'farmer') {
            return FarmerDashboard(farmerId: userId);
          }
        } else {
          print('⚠️ Firebase session outdated, clearing...');
          await SimpleStorageService.clearUserSession();
        }
      }
    } else {
      print('❌ No valid local session found');
    }
    
    // No valid local session, check Firebase Auth for collectors
    final firebaseUser = FirebaseAuth.instance.currentUser;
    
    if (firebaseUser != null) {
      // User is authenticated with Firebase but no local session
      print('👤 Firebase user found but no local session - checking Firestore role');
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (doc.exists) {
          final userData = doc.data();
          final role = userData?['role'];
          
          if (role == 'collector') {
            // Save session and redirect
            await SimpleStorageService.saveFirebaseSession(
              userId: firebaseUser.uid,
              userEmail: firebaseUser.email ?? '',
              role: 'collector',
            );
            return const CollectorDashboard();
          } else if (role == 'farmer') {
            await SimpleStorageService.saveFirebaseSession(
              userId: firebaseUser.uid,
              userEmail: firebaseUser.email ?? '',
              role: 'farmer',
            );
            return FarmerDashboard(farmerId: firebaseUser.uid);
          }
        }
      } catch (e) {
        print('❌ Error checking Firestore: $e');
      }
    }

    // No valid session - show role selection
    print('🚪 No valid session - showing RoleSelectionScreen');
    return const RoleSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkLocalSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your session...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('💥 Error in auth gate: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Error loading app'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final screen = snapshot.data;
        print('🏁 Final screen: ${screen.runtimeType}');
        return screen ?? const RoleSelectionScreen();
      },
    );
  }
}