import 'package:cloud_firestore/cloud_firestore.dart';

class PricingService {
  static const double _defaultPrice = 45.0;

  /// Fetches the current milk price per liter.
  /// 
  /// Strategy:
  /// 1. Check 'system_config/milk_price'
  /// 2. Check most recent 'milk_payment' in 'payments' collection
  /// 3. Check most recent 'paid' entry in 'milk_logs'
  /// 4. Fallback to default (45.0)
  Future<double> getCurrentMilkPrice() async {
    try {
      // 1. System Config
      final configDoc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('milk_price')
          .get();
      
      if (configDoc.exists && configDoc.data() != null) {
        final data = configDoc.data()!;
        if (data.containsKey('pricePerLiter')) {
          return (data['pricePerLiter'] as num).toDouble();
        }
      }

      // 2. Recent Payment
      final paymentQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('type', isEqualTo: 'milk_payment')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (paymentQuery.docs.isNotEmpty) {
        final data = paymentQuery.docs.first.data();
        if (data.containsKey('pricePerLiter')) {
          return (data['pricePerLiter'] as num).toDouble();
        }
      }

      // 3. Recent Log (Last resort for historical accuracy)
      final logQuery = await FirebaseFirestore.instance
          .collection('milk_logs')
          .where('status', isEqualTo: 'paid')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (logQuery.docs.isNotEmpty) {
        final data = logQuery.docs.first.data();
        if (data.containsKey('pricePerLiter')) {
          return (data['pricePerLiter'] as num).toDouble();
        }
      }

      return _defaultPrice;
    } catch (e) {
      // Fail silently to default
      return _defaultPrice;
    }
  }
}
