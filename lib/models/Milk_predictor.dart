// lib/models/Milk_predictor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MilkPredictor {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main prediction method that returns predictions for multiple timeframes
  Future<Map<String, dynamic>> predictMilkProduction(String farmerId) async {
    try {
      // Fetch more historical data for better predictions
      final snapshot = await _firestore
          .collection("milk_logs")
          .where("farmerId", isEqualTo: farmerId)
          .orderBy("date", descending: true)
          .limit(90) // Last 90 days for better pattern recognition
          .get();

      final logs = snapshot.docs;
      if (logs.isEmpty) {
        return _getDefaultPredictions();
      }

      // Process and analyze the data
      final milkData = _processMilkData(logs);
      
      // Generate predictions for different timeframes
      final dailyPrediction = _predictDailyProduction(milkData);
      final weeklyPrediction = _predictWeeklyProduction(milkData);
      final monthlyPrediction = _predictMonthlyProduction(milkData);
      final yearlyPrediction = _predictYearlyProduction(milkData);

      // Calculate overall confidence based on data quality
      final confidence = _calculateConfidence(milkData);

      return {
        'daily': dailyPrediction,
        'weekly': weeklyPrediction,
        'monthly': monthlyPrediction,
        'yearly': yearlyPrediction,
        'confidence': confidence,
        'dataPoints': milkData.length,
        'trend': _calculateTrend(milkData),
        'seasonality': _detectSeasonality(milkData),
        'lastUpdated': DateTime.now(),
      };
      
    } catch (e) {
      print("Prediction error: $e");
      return _getDefaultPredictions();
    }
  }

  /// Process raw Firestore data into structured format
  List<MilkDataPoint> _processMilkData(List<QueryDocumentSnapshot> logs) {
    final milkData = <MilkDataPoint>[];
    
    for (final doc in logs.reversed) { // Chronological order
      final data = doc.data() as Map<String, dynamic>;
      final date = (data["date"] as Timestamp).toDate();
      final quantity = (data["quantity"] ?? 0).toDouble();
      
      if (quantity > 0) {
        milkData.add(MilkDataPoint(
          date: date,
          quantity: quantity,
          dayOfWeek: date.weekday,
          month: date.month,
          year: date.year,
        ));
      }
    }
    
    return milkData;
  }

  /// Predict next day's milk production using multiple algorithms
  DailyPrediction _predictDailyProduction(List<MilkDataPoint> milkData) {
    if (milkData.length < 3) {
      final avg = _calculateSimpleAverage(milkData);
      return DailyPrediction(
        prediction: avg,
        confidence: 0.3,
        method: 'average',
        trend: 'stable',
      );
    }

    // Use multiple prediction methods and combine them
    final recentAvg = _calculateRecentAverage(milkData, 7);
    final weightedAvg = _calculateWeightedAverage(milkData, 14);
    final movingAvg = _calculateExponentialMovingAverage(milkData, 0.3);
    final seasonalAdj = _applySeasonalAdjustment(milkData, 'daily');
    final regressionPred = _linearRegressionPrediction(milkData);

    // Combine predictions with weights
    final combinedPrediction = (recentAvg * 0.3) + 
                              (weightedAvg * 0.25) + 
                              (movingAvg * 0.2) + 
                              (seasonalAdj * 0.15) + 
                              (regressionPred * 0.1);

    // Determine trend - FIXED: Return String instead of double
    final trend = _calculateShortTermTrend(milkData);

    return DailyPrediction(
      prediction: combinedPrediction,
      confidence: _calculateDailyConfidence(milkData),
      method: 'combined',
      trend: trend,
      components: {
        'recentAverage': recentAvg,
        'weightedAverage': weightedAvg,
        'movingAverage': movingAvg,
        'seasonalAdjustment': seasonalAdj,
        'regression': regressionPred,
      },
    );
  }

  /// Predict weekly production
  WeeklyPrediction _predictWeeklyProduction(List<MilkDataPoint> milkData) {
    if (milkData.length < 14) {
      final weeklyAvg = _calculateWeeklyAverage(milkData);
      return WeeklyPrediction(
        prediction: weeklyAvg * 7, // Estimate full week
        confidence: 0.4,
        trend: 'stable',
      );
    }

    // Group by weeks and analyze patterns
    final weeklyData = _groupByWeeks(milkData);
    final weeklyPrediction = _predictTimeSeries(weeklyData, 4) * 7;

    return WeeklyPrediction(
      prediction: weeklyPrediction,
      confidence: _calculateWeeklyConfidence(weeklyData),
      trend: _calculateWeeklyTrend(weeklyData),
      averageDaily: weeklyPrediction / 7,
    );
  }

  /// Predict monthly production
  MonthlyPrediction _predictMonthlyProduction(List<MilkDataPoint> milkData) {
    if (milkData.length < 30) {
      final monthlyEst = _estimateMonthlyFromDaily(milkData);
      return MonthlyPrediction(
        prediction: monthlyEst,
        confidence: 0.5,
        trend: 'stable',
      );
    }

    // Group by months and analyze
    final monthlyData = _groupByMonths(milkData);
    final monthlyPrediction = _predictTimeSeries(monthlyData, 3);

    // Consider seasonal factors
    final currentMonth = DateTime.now().month;
    final seasonalFactor = _getSeasonalFactor(currentMonth);

    return MonthlyPrediction(
      prediction: monthlyPrediction * seasonalFactor,
      confidence: _calculateMonthlyConfidence(monthlyData),
      trend: _calculateMonthlyTrend(monthlyData),
      seasonalFactor: seasonalFactor,
      averageDaily: monthlyPrediction / 30,
    );
  }

  /// Predict yearly production
  YearlyPrediction _predictYearlyProduction(List<MilkDataPoint> milkData) {
    if (milkData.length < 180) { // Need at least 6 months of data
      final yearlyEst = _estimateYearlyFromAvailableData(milkData);
      return YearlyPrediction(
        prediction: yearlyEst,
        confidence: 0.3,
        trend: 'stable',
      );
    }

    // Group by years and analyze
    final yearlyData = _groupByYears(milkData);
    final yearlyPrediction = _predictTimeSeries(yearlyData, 2);

    // Apply growth rate based on historical trend
    final growthRate = _calculateGrowthRate(yearlyData);
    final adjustedPrediction = yearlyPrediction * (1 + growthRate);

    return YearlyPrediction(
      prediction: adjustedPrediction,
      confidence: _calculateYearlyConfidence(yearlyData),
      trend: growthRate > 0.05 ? 'growing' : growthRate < -0.05 ? 'declining' : 'stable',
      growthRate: growthRate,
      projectedMonthly: adjustedPrediction / 12,
    );
  }

  // === FIXED METHODS WITH CORRECT RETURN TYPES ===

  String _calculateShortTermTrend(List<MilkDataPoint> data) { // Changed to String
    if (data.length < 7) return 'stable';
    
    final recentWeek = data.length > 7 ? data.sublist(data.length - 7) : data;
    final previousWeek = data.length > 14 ? 
        data.sublist(data.length - 14, data.length - 7) : 
        data.sublist(0, data.length ~/ 2);
    
    final recentAvg = _calculateSimpleAverage(recentWeek);
    final previousAvg = _calculateSimpleAverage(previousWeek);
    
    final change = (recentAvg - previousAvg) / previousAvg;
    
    if (change > 0.1) return 'growing';
    if (change < -0.1) return 'declining';
    return 'stable';
  }

  double _calculateWeeklyAverage(List<MilkDataPoint> data) {
    if (data.isEmpty) return 15.0;
    final last7Days = data.length > 7 ? data.sublist(data.length - 7) : data;
    return _calculateSimpleAverage(last7Days);
  }

  double _calculateWeeklyConfidence(List<double> weeklyData) {
    if (weeklyData.isEmpty) return 0.1;
    return (weeklyData.length / 8).clamp(0.0, 1.0); // Max 8 weeks
  }

  String _calculateWeeklyTrend(List<double> weeklyData) {
    if (weeklyData.length < 2) return 'stable';
    
    final recent = weeklyData.last;
    final previous = weeklyData[weeklyData.length - 2];
    final change = (recent - previous) / previous;
    
    if (change > 0.1) return 'growing';
    if (change < -0.1) return 'declining';
    return 'stable';
  }

  double _estimateMonthlyFromDaily(List<MilkDataPoint> data) {
    final dailyAvg = _calculateSimpleAverage(data);
    return dailyAvg * 30; // Estimate month from daily average
  }

  double _calculateMonthlyConfidence(List<double> monthlyData) {
    if (monthlyData.isEmpty) return 0.1;
    return (monthlyData.length / 6).clamp(0.0, 1.0); // Max 6 months
  }

  String _calculateMonthlyTrend(List<double> monthlyData) {
    if (monthlyData.length < 2) return 'stable';
    
    final recent = monthlyData.last;
    final previous = monthlyData[monthlyData.length - 2];
    final change = (recent - previous) / previous;
    
    if (change > 0.05) return 'growing';
    if (change < -0.05) return 'declining';
    return 'stable';
  }

  double _estimateYearlyFromAvailableData(List<MilkDataPoint> data) {
    final dailyAvg = _calculateSimpleAverage(data);
    return dailyAvg * 365; // Estimate year from daily average
  }

  double _calculateYearlyConfidence(List<double> yearlyData) {
    if (yearlyData.isEmpty) return 0.1;
    return (yearlyData.length / 3).clamp(0.0, 1.0); // Max 3 years
  }

  // === MATHEMATICAL MODELS ===

  /// Linear regression prediction
  double _linearRegressionPrediction(List<MilkDataPoint> data) {
    if (data.length < 2) return _calculateSimpleAverage(data);
    
    final n = data.length.toDouble();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for (int i = 0; i < data.length; i++) {
      final x = i.toDouble();
      final y = data[i].quantity;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    
    return slope * n + intercept;
  }

  /// Exponential moving average
  double _calculateExponentialMovingAverage(List<MilkDataPoint> data, double alpha) {
    if (data.isEmpty) return 0.0;
    
    double ema = data.first.quantity;
    for (int i = 1; i < data.length; i++) {
      ema = alpha * data[i].quantity + (1 - alpha) * ema;
    }
    
    return ema;
  }

  /// Time series prediction using ARIMA-like approach
  double _predictTimeSeries(List<double> series, int periods) {
    if (series.isEmpty) return 0.0;
    if (series.length == 1) return series.first;
    
    // Simple moving average of recent periods
    final recentPeriods = periods < series.length ? periods : series.length;
    double sum = 0;
    for (int i = series.length - recentPeriods; i < series.length; i++) {
      sum += series[i];
    }
    
    return sum / recentPeriods;
  }

  // === DATA PROCESSING METHODS ===

  List<double> _groupByWeeks(List<MilkDataPoint> data) {
    final weeklySums = <double>[];
    double weeklySum = 0;
    DateTime? currentWeek;
    
    for (final point in data) {
      final pointWeek = _getWeekStart(point.date);
      
      if (currentWeek == null) {
        currentWeek = pointWeek;
      }
      
      if (pointWeek != currentWeek) {
        weeklySums.add(weeklySum);
        weeklySum = 0;
        currentWeek = pointWeek;
      }
      
      weeklySum += point.quantity;
    }
    
    if (weeklySum > 0) {
      weeklySums.add(weeklySum);
    }
    
    return weeklySums;
  }

  List<double> _groupByMonths(List<MilkDataPoint> data) {
    final monthlySums = <double>[];
    double monthlySum = 0;
    DateTime? currentMonth;
    
    for (final point in data) {
      final pointMonth = DateTime(point.date.year, point.date.month);
      
      if (currentMonth == null) {
        currentMonth = pointMonth;
      }
      
      if (pointMonth != currentMonth) {
        monthlySums.add(monthlySum);
        monthlySum = 0;
        currentMonth = pointMonth;
      }
      
      monthlySum += point.quantity;
    }
    
    if (monthlySum > 0) {
      monthlySums.add(monthlySum);
    }
    
    return monthlySums;
  }

  List<double> _groupByYears(List<MilkDataPoint> data) {
    final yearlySums = <int, double>{};
    
    for (final point in data) {
      final year = point.date.year;
      yearlySums[year] = (yearlySums[year] ?? 0.0) + point.quantity;
    }
    
    return yearlySums.values.toList();
  }

  // === CONFIDENCE CALCULATIONS ===

  double _calculateConfidence(List<MilkDataPoint> data) {
    if (data.isEmpty) return 0.1;
    
    final dataPointsScore = (data.length / 90).clamp(0.0, 1.0); // Max 90 days
    final recencyScore = _calculateRecencyScore(data);
    const consistencyScore = 0.7; // Could be calculated from variance
    
    return (dataPointsScore * 0.4 + recencyScore * 0.4 + consistencyScore * 0.2);
  }

  double _calculateDailyConfidence(List<MilkDataPoint> data) {
    final baseConfidence = _calculateConfidence(data);
    final recentData = data.length >= 7 ? 0.8 : 0.5;
    return (baseConfidence + recentData) / 2;
  }

  double _calculateRecencyScore(List<MilkDataPoint> data) {
    if (data.isEmpty) return 0.0;
    
    final latestDate = data.last.date;
    final daysSinceLatest = DateTime.now().difference(latestDate).inDays;
    
    if (daysSinceLatest <= 1) return 1.0;
    if (daysSinceLatest <= 3) return 0.8;
    if (daysSinceLatest <= 7) return 0.6;
    if (daysSinceLatest <= 14) return 0.4;
    return 0.2;
  }

  // === TREND ANALYSIS ===

  String _calculateTrend(List<MilkDataPoint> data) {
    if (data.length < 7) return 'insufficient_data';
    
    final recentAvg = _calculateRecentAverage(data, 7);
    final previousAvg = _calculateRecentAverage(data.sublist(0, data.length - 7), 7);
    
    if (recentAvg > previousAvg * 1.1) return 'growing';
    if (recentAvg < previousAvg * 0.9) return 'declining';
    return 'stable';
  }

  double _calculateGrowthRate(List<double> series) {
    if (series.length < 2) return 0.0;
    
    final recent = series.last;
    final previous = series[series.length - 2];
    return (recent - previous) / previous;
  }

  // === SEASONALITY AND EXTERNAL FACTORS ===

  double _getSeasonalFactor(int month) {
    // Adjust based on typical dairy farming seasons
    const factors = {
      1: 1.0, 2: 1.0, 3: 1.1, 4: 1.2, 5: 1.1, 6: 1.0,
      7: 0.9, 8: 0.9, 9: 1.0, 10: 1.0, 11: 1.0, 12: 1.0
    };
    return factors[month] ?? 1.0;
  }

  String _detectSeasonality(List<MilkDataPoint> data) {
    if (data.length < 60) return 'insufficient_data';
    
    // Simple seasonality detection based on monthly patterns
    final monthlyAvgs = <int, List<double>>{};
    
    for (final point in data) {
      final month = point.date.month;
      monthlyAvgs[month] ??= [];
      monthlyAvgs[month]!.add(point.quantity);
    }
    
    // Check if any month consistently differs from average
    final overallAvg = _calculateSimpleAverage(data);
    for (final monthData in monthlyAvgs.entries) {
      final monthAvg = monthData.value.reduce((a, b) => a + b) / monthData.value.length;
      if (monthAvg > overallAvg * 1.15 || monthAvg < overallAvg * 0.85) {
        return 'seasonal';
      }
    }
    
    return 'non_seasonal';
  }

  // === HELPER METHODS ===

  double _calculateSimpleAverage(List<MilkDataPoint> data) {
    if (data.isEmpty) return 15.0;
    return data.map((e) => e.quantity).reduce((a, b) => a + b) / data.length;
  }

  double _calculateRecentAverage(List<MilkDataPoint> data, int days) {
    final recentData = data.length > days ? data.sublist(data.length - days) : data;
    return _calculateSimpleAverage(recentData);
  }

  double _calculateWeightedAverage(List<MilkDataPoint> data, int maxDays) {
    final effectiveDays = data.length < maxDays ? data.length : maxDays;
    double total = 0;
    double weightSum = 0;
    
    for (int i = 0; i < effectiveDays; i++) {
      final weight = (effectiveDays - i).toDouble();
      total += data[data.length - 1 - i].quantity * weight;
      weightSum += weight;
    }
    
    return weightSum > 0 ? total / weightSum : _calculateSimpleAverage(data);
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  double _applySeasonalAdjustment(List<MilkDataPoint> data, String timeframe) {
    final basePrediction = _calculateRecentAverage(data, 7);
    final currentMonth = DateTime.now().month;
    final factor = _getSeasonalFactor(currentMonth);
    return basePrediction * factor;
  }

  Map<String, dynamic> _getDefaultPredictions() {
    return {
      'daily': DailyPrediction(prediction: 15.0, confidence: 0.1, method: 'default', trend: 'stable'),
      'weekly': WeeklyPrediction(prediction: 105.0, confidence: 0.1, trend: 'stable'),
      'monthly': MonthlyPrediction(prediction: 450.0, confidence: 0.1, trend: 'stable'),
      'yearly': YearlyPrediction(prediction: 5400.0, confidence: 0.1, trend: 'stable'),
      'confidence': 0.1,
      'dataPoints': 0,
      'trend': 'insufficient_data',
      'seasonality': 'unknown',
      'lastUpdated': DateTime.now(),
    };
  }

  // Backward compatibility
  Future<double> predictNextMilk(String farmerId) async {
    final predictions = await predictMilkProduction(farmerId);
    return (predictions['daily'] as DailyPrediction).prediction;
  }

  Future<Map<String, dynamic>> predictNextMilkWithConfidence(String farmerId) async {
    final predictions = await predictMilkProduction(farmerId);
    final daily = predictions['daily'] as DailyPrediction;
    return {
      'prediction': daily.prediction,
      'confidence': predictions['confidence'] ?? 0.1,
      'dataPoints': predictions['dataPoints'] ?? 0,
    };
  }
}

// Data Models
class MilkDataPoint {
  final DateTime date;
  final double quantity;
  final int dayOfWeek;
  final int month;
  final int year;

  MilkDataPoint({
    required this.date,
    required this.quantity,
    required this.dayOfWeek,
    required this.month,
    required this.year,
  });
}

class DailyPrediction {
  final double prediction;
  final double confidence;
  final String method;
  final String trend;
  final Map<String, double>? components;

  DailyPrediction({
    required this.prediction,
    required this.confidence,
    required this.method,
    required this.trend,
    this.components,
  });
}

class WeeklyPrediction {
  final double prediction;
  final double confidence;
  final String trend;
  final double averageDaily;

  WeeklyPrediction({
    required this.prediction,
    required this.confidence,
    required this.trend,
    this.averageDaily = 0.0,
  });
}

class MonthlyPrediction {
  final double prediction;
  final double confidence;
  final String trend;
  final double seasonalFactor;
  final double averageDaily;

  MonthlyPrediction({
    required this.prediction,
    required this.confidence,
    required this.trend,
    this.seasonalFactor = 1.0,
    this.averageDaily = 0.0,
  });
}

class YearlyPrediction {
  final double prediction;
  final double confidence;
  final String trend;
  final double growthRate;
  final double projectedMonthly;

  YearlyPrediction({
    required this.prediction,
    required this.confidence,
    required this.trend,
    this.growthRate = 0.0,
    this.projectedMonthly = 0.0,
  });
}