import 'package:flutter/foundation.dart';

/// Advanced scoring service implementing weighted phase scoring and Bayesian adjustments
class ScoringService {
  // Phase weights
  static const double PRE_FLIGHT_WEIGHT = 0.20; // 20%
  static const double IN_FLIGHT_WEIGHT = 0.30; // 30%
  static const double POST_FLIGHT_WEIGHT = 0.50; // 50%

  // Bayesian smoothing parameters
  static const int MINIMUM_VOLUME = 30; // Minimum reviews for reliable scoring
  static const double GLOBAL_AVERAGE =
      3.5; // Global average across all airlines

  /// Calculate overall score using weighted phases
  static ScoringResult calculateOverallScore({
    double? preFlightScore,
    double? inFlightScore,
    double? postFlightScore,
    double? catchUpScore,
  }) {
    // Count completed phases
    int phasesCompleted = 0;
    if (preFlightScore != null) phasesCompleted++;
    if (inFlightScore != null) phasesCompleted++;
    if (postFlightScore != null) phasesCompleted++;

    // Apply scoring rules
    if (phasesCompleted == 0) {
      return ScoringResult(
        overallScore: null,
        phasesCompleted: 0,
        confidenceLevel: 'none',
        calculationMethod: 'No phases completed',
        breakdown: {},
      );
    }

    if (phasesCompleted == 1) {
      // Single phase - return that score
      double? singleScore;
      String phase;

      if (preFlightScore != null) {
        singleScore = preFlightScore;
        phase = 'pre-flight';
      } else if (inFlightScore != null) {
        singleScore = inFlightScore;
        phase = 'in-flight';
      } else {
        singleScore = postFlightScore;
        phase = 'post-flight';
      }

      return ScoringResult(
        overallScore: singleScore,
        phasesCompleted: 1,
        confidenceLevel: 'low',
        calculationMethod: 'Single phase: $phase',
        breakdown: {
          phase: singleScore,
        },
      );
    }

    // Multiple phases - use weighted average with catch-up logic
    Map<String, double> weights = {};
    Map<String, double> scores = {};

    // Apply catch-up scoring rules
    if (postFlightScore != null) {
      // Post-flight completed - can scale up weights
      if (phasesCompleted == 2) {
        // Two phases including post-flight - scale up to 100%
        if (preFlightScore != null && inFlightScore != null) {
          // Pre + In + Post: Use original weights (already sum to 100%)
          weights = {
            'pre-flight': PRE_FLIGHT_WEIGHT,
            'in-flight': IN_FLIGHT_WEIGHT,
            'post-flight': POST_FLIGHT_WEIGHT,
          };
          scores = {
            'pre-flight': preFlightScore,
            'in-flight': inFlightScore,
            'post-flight': postFlightScore,
          };
        } else if (preFlightScore != null) {
          // Pre + Post: Scale pre to 20%, post to 80%
          weights = {'pre-flight': 0.20, 'post-flight': 0.80};
          scores = {
            'pre-flight': preFlightScore,
            'post-flight': postFlightScore
          };
        } else if (inFlightScore != null) {
          // In + Post: Scale in to 30%, post to 70%
          weights = {'in-flight': 0.30, 'post-flight': 0.70};
          scores = {'in-flight': inFlightScore, 'post-flight': postFlightScore};
        }
      } else {
        // All three phases
        weights = {
          'pre-flight': PRE_FLIGHT_WEIGHT,
          'in-flight': IN_FLIGHT_WEIGHT,
          'post-flight': POST_FLIGHT_WEIGHT,
        };
        scores = {
          'pre-flight': preFlightScore,
          'in-flight': inFlightScore ?? catchUpScore ?? 0,
          'post-flight': postFlightScore,
        };
      }
    } else {
      // No post-flight - use catch-up or scale existing phases
      if (catchUpScore != null) {
        // Use catch-up for missing phases
        if (preFlightScore != null && inFlightScore != null) {
          // Pre + In + Catch-up for Post
          weights = {
            'pre-flight': PRE_FLIGHT_WEIGHT,
            'in-flight': IN_FLIGHT_WEIGHT,
            'post-flight': POST_FLIGHT_WEIGHT,
          };
          scores = {
            'pre-flight': preFlightScore,
            'in-flight': inFlightScore,
            'post-flight': catchUpScore,
          };
        } else if (preFlightScore != null) {
          // Pre + Catch-up for In + Post
          weights = {
            'pre-flight': PRE_FLIGHT_WEIGHT,
            'catch-up': IN_FLIGHT_WEIGHT + POST_FLIGHT_WEIGHT
          };
          scores = {'pre-flight': preFlightScore, 'catch-up': catchUpScore};
        } else if (inFlightScore != null) {
          // In + Catch-up for Pre + Post
          weights = {
            'in-flight': IN_FLIGHT_WEIGHT,
            'catch-up': PRE_FLIGHT_WEIGHT + POST_FLIGHT_WEIGHT
          };
          scores = {'in-flight': inFlightScore, 'catch-up': catchUpScore};
        }
      } else {
        // Scale existing phases to 100%
        if (preFlightScore != null && inFlightScore != null) {
          // Pre + In: Scale to 100% (40% pre, 60% in)
          weights = {'pre-flight': 0.40, 'in-flight': 0.60};
          scores = {'pre-flight': preFlightScore, 'in-flight': inFlightScore};
        }
      }
    }

    // Calculate weighted average
    double totalWeight = 0;
    double weightedSum = 0;

    scores.forEach((phase, score) {
      double weight = weights[phase] ?? 0;
      totalWeight += weight;
      weightedSum += score * weight;
    });

    double overallScore = totalWeight > 0 ? weightedSum / totalWeight : 0;

    // Determine confidence level
    String confidenceLevel = _getConfidenceLevel(phasesCompleted);

    // Determine calculation method
    String calculationMethod = _getCalculationMethod(
        phasesCompleted, scores.keys.toList(), catchUpScore != null);

    return ScoringResult(
      overallScore: overallScore,
      phasesCompleted: phasesCompleted,
      confidenceLevel: confidenceLevel,
      calculationMethod: calculationMethod,
      breakdown: scores,
    );
  }

  /// Apply Bayesian smoothing to prevent inflated scores from small sample sizes
  static BayesianScore applyBayesianSmoothing({
    required double rawScore,
    required int reviewCount,
    required double globalAverage,
  }) {
    if (reviewCount >= MINIMUM_VOLUME) {
      // High volume - use raw score
      return BayesianScore(
        rawScore: rawScore,
        bayesianScore: rawScore,
        reviewCount: reviewCount,
        confidenceLevel: 'high',
        label: rawScore > 4.5 ? 'Top Rated' : 'Reliable',
      );
    }

    // Apply Bayesian formula: (v/(v+m)) * S + (m/(v+m)) * C
    double v = reviewCount.toDouble();
    double m = MINIMUM_VOLUME.toDouble();
    double S = rawScore;
    double C = globalAverage;

    double bayesianScore = (v / (v + m)) * S + (m / (v + m)) * C;

    String confidenceLevel = _getBayesianConfidenceLevel(reviewCount);
    String label = _getBayesianLabel(reviewCount, bayesianScore);

    return BayesianScore(
      rawScore: rawScore,
      bayesianScore: bayesianScore,
      reviewCount: reviewCount,
      confidenceLevel: confidenceLevel,
      label: label,
    );
  }

  /// Get confidence level based on number of completed phases
  static String _getConfidenceLevel(int phasesCompleted) {
    switch (phasesCompleted) {
      case 0:
        return 'none';
      case 1:
        return 'low';
      case 2:
        return 'medium';
      case 3:
        return 'high';
      default:
        return 'low';
    }
  }

  /// Get calculation method description
  static String _getCalculationMethod(
      int phasesCompleted, List<String> phases, bool usedCatchUp) {
    if (phasesCompleted == 0) return 'No phases completed';
    if (phasesCompleted == 1) return 'Single phase only';

    String phaseList = phases.join(', ');
    String method = 'Weighted average of $phaseList';

    if (usedCatchUp) {
      method += ' (with catch-up estimation)';
    }

    return method;
  }

  /// Get Bayesian confidence level
  static String _getBayesianConfidenceLevel(int reviewCount) {
    if (reviewCount >= 51) return 'high';
    if (reviewCount >= 11) return 'medium';
    return 'low';
  }

  /// Get Bayesian label
  static String _getBayesianLabel(int reviewCount, double score) {
    if (reviewCount == 0) return 'No data';
    if (reviewCount <= 10) return 'Still collecting data';
    if (reviewCount <= 50) return 'New Entry';
    if (score > 4.5) return 'Top Rated';
    return 'Established';
  }
}

/// Result of overall score calculation
class ScoringResult {
  final double? overallScore;
  final int phasesCompleted;
  final String confidenceLevel;
  final String calculationMethod;
  final Map<String, double> breakdown;

  const ScoringResult({
    required this.overallScore,
    required this.phasesCompleted,
    required this.confidenceLevel,
    required this.calculationMethod,
    required this.breakdown,
  });

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() {
    return {
      'overallScore': overallScore,
      'phasesCompleted': phasesCompleted,
      'confidenceLevel': confidenceLevel,
      'calculationMethod': calculationMethod,
      'breakdown': breakdown,
      'preScore': breakdown['pre-flight'],
      'duringScore': breakdown['in-flight'],
      'postScore': breakdown['post-flight'],
    };
  }
}

/// Result of Bayesian smoothing calculation
class BayesianScore {
  final double rawScore;
  final double bayesianScore;
  final int reviewCount;
  final String confidenceLevel;
  final String label;

  const BayesianScore({
    required this.rawScore,
    required this.bayesianScore,
    required this.reviewCount,
    required this.confidenceLevel,
    required this.label,
  });

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() {
    return {
      'rawScore': rawScore,
      'bayesianScore': bayesianScore,
      'reviewCount': reviewCount,
      'confidenceLevel': confidenceLevel,
      'label': label,
    };
  }
}
