import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerListScreen extends StatelessWidget {
  const FarmerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final collectorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("My Farmers")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where("role", isEqualTo: "farmer")
            .where("collectorId", isEqualTo: collectorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No farmers registered yet."));
          }

          final farmers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: farmers.length,
            itemBuilder: (context, index) {
              final farmer = farmers[index];
              return ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: Text(farmer["name"]),
                subtitle: Text(farmer["phone"]),
                trailing: IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue),
                  onPressed: () {
                    // 👉 Navigate to LogMilkScreen with farmer details
                    Navigator.pushNamed(
                      context,
                      "/logMilk",
                      arguments: {
                        "farmerId": farmer.id,
                        "name": farmer["name"],
                        "phone": farmer["phone"],
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
