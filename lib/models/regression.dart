// lib/mmodels/regression.dart
class LinearRegression {
  static Map<String, double> train(List<double> x, List<double> y) {
    if (x.isEmpty || y.isEmpty || x.length != y.length) {
      throw ArgumentError('Input arrays must be non-empty and of equal length');
    }

    final n = x.length;
    
    // Calculate means
    final xMean = _mean(x);
    final yMean = _mean(y);
    
    // Calculate slope (m) and intercept (b) for y = mx + b
    double numerator = 0.0;
    double denominator = 0.0;
    
    for (int i = 0; i < n; i++) {
      numerator += (x[i] - xMean) * (y[i] - yMean);
      denominator += (x[i] - xMean) * (x[i] - xMean);
    }
    
    // Avoid division by zero
    if (denominator == 0) {
      return {'slope': 0.0, 'intercept': yMean};
    }
    
    final slope = numerator / denominator;
    final intercept = yMean - slope * xMean;
    
    return {'slope': slope, 'intercept': intercept};
  }
  
  static double predict(double x, Map<String, double> model) {
    final slope = model['slope'] ?? 0.0;
    final intercept = model['intercept'] ?? 0.0;
    return slope * x + intercept;
  }
  
  static double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}