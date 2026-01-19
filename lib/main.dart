import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';

import 'package:podago/screens/auth/login_screen.dart';
import 'package:podago/screens/auth/role_selection_screen.dart';
import 'package:podago/screens/farmer/dashboard_farmer.dart';
import 'package:podago/screens/collector/dashboard_collector.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:podago/services/simple_storage_service.dart';
import 'package:podago/utils/app_theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PodagoApp());
}



class PodagoApp extends StatelessWidget {
  const PodagoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Podago',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Use the new theme
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
    debugPrint('🕵️ Checking local session...');
    final localSession = await SimpleStorageService.getUserSession();

    debugPrint('📱 Local storage data: $localSession');

    if (localSession != null &&
        await SimpleStorageService.hasValidSession()) {
      final role = localSession['role'];
      final userId = localSession['userId'];
      final authType = localSession['authType'];

      debugPrint(
          '🎯 Found valid local session: $role for user: $userId (Auth: $authType)');

      if (authType == 'pin') {
        debugPrint('🔐 PIN-based session → FarmerDashboard');
        return FarmerDashboard(farmerId: userId);
      } else {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        debugPrint('🔥 Firebase current user: $firebaseUser');

        if (firebaseUser != null && firebaseUser.uid == userId) {
          debugPrint('✅ Firebase session verified');

          if (role == 'collector') {
            return const CollectorDashboard();
          } else if (role == 'farmer') {
            return FarmerDashboard(farmerId: userId);
          }
        } else {
          debugPrint('⚠️ Firebase session outdated → clearing');
          await SimpleStorageService.clearUserSession();
        }
      }
    } else {
      debugPrint('❌ No valid local session found');
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      debugPrint(
          '👤 Firebase user found but no local session → checking Firestore');

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (doc.exists) {
          final role = doc.data()?['role'];

          if (role == 'collector') {
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
        debugPrint('❌ Firestore error: $e');
      }
    }

    debugPrint('🚪 No valid session → RoleSelectionScreen');
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
          debugPrint('💥 AuthGate error: ${snapshot.error}');
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
        debugPrint('🏁 Final screen: ${screen.runtimeType}');
        return screen ?? const RoleSelectionScreen();
      },
    );
  }
}
