import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LogMilkScreen extends StatefulWidget {
  const LogMilkScreen({super.key});

  @override
  State<LogMilkScreen> createState() => _LogMilkScreenState();
}

class _LogMilkScreenState extends State<LogMilkScreen> {
  String? selectedFarmerId;
  String? selectedFarmerName;
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a farmer"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final quantity = double.tryParse(quantityCtrl.text.trim()) ?? 0;
      final notes = notesCtrl.text.trim();

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      await FirebaseFirestore.instance.collection("milk_logs").add({
        "farmerId": selectedFarmerId,
        "farmerName": selectedFarmerName,
        "quantity": quantity,
        "notes": notes,
        "date": now,
        "dateStr": dateStr,
        "status": "pending",
        "timestamp": FieldValue.serverTimestamp(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Milk collection logged successfully!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back after a brief delay to show success message
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save log: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter milk quantity';
    }
    final quantity = double.tryParse(value);
    if (quantity == null) {
      return 'Please enter a valid number';
    }
    if (quantity <= 0) {
      return 'Quantity must be greater than zero';
    }
    if (quantity > 1000) {
      return 'Quantity seems unusually high';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Log Milk Collection",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Section
              _buildHeaderSection(),
              const SizedBox(height: 32),

              // Form Section
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildFarmerSelection(),
                        const SizedBox(height: 20),
                        _buildQuantityInput(),
                        const SizedBox(height: 20),
                        _buildNotesInput(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.water_drop_rounded,
            color: Colors.green[700],
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "New Milk Collection",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Record milk quantity collected from farmers",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildFarmerSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Farmer *",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .where("role", isEqualTo: "farmer")
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "Error loading farmers",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }

            final farmers = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              value: selectedFarmerId,
              decoration: InputDecoration(
                hintText: "Select farmer",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline_rounded),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.shade700),
                ),
              ),
              items: farmers.map((farmer) {
                final data = farmer.data() as Map<String, dynamic>;
                final name = data["name"] ?? "Unnamed Farmer";
                final phone = data["phone"] ?? "";
                return DropdownMenuItem<String>(
                  value: farmer.id,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (phone.isNotEmpty)
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    selectedFarmerName = name;
                  },
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedFarmerId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a farmer';
                }
                return null;
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuantityInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quantity (Liters) *",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: quantityCtrl,
          decoration: const InputDecoration(
            labelText: "Enter quantity in liters",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.scale_rounded),
            suffixText: "L",
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: _validateQuantity,
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Notes",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: "Additional notes (optional)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note_add_outlined),
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _saveLog,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_alt_rounded),
            label: Text(
              _isSubmitting ? "Saving..." : "Save Milk Collection",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (_formKey.currentState != null) {
                      _formKey.currentState!.reset();
                    }
                    quantityCtrl.clear();
                    notesCtrl.clear();
                    setState(() {
                      selectedFarmerId = null;
                      selectedFarmerName = null;
                    });
                    FocusScope.of(context).unfocus();
                  },
            child: const Text(
              "Clear Form",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    quantityCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }
}