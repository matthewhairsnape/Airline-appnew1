import 'package:flutter/material.dart';

enum FeedbackStage {
  preFlight,
  inFlight,
  postFlight,
}

enum FeedbackType {
  positive,
  negative,
}

class FeedbackOption {
  final String id;
  final String text;
  final String? icon;
  final bool isCustom;

  const FeedbackOption({
    required this.id,
    required this.text,
    this.icon,
    this.isCustom = false,
  });

  factory FeedbackOption.fromJson(Map<String, dynamic> json) {
    return FeedbackOption(
      id: json['id'],
      text: json['text'],
      icon: json['icon'],
      isCustom: json['isCustom'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'icon': icon,
      'isCustom': isCustom,
    };
  }
}

class StageFeedback {
  final String id;
  final FeedbackStage stage;
  final String flightId;
  final String pnr;
  final DateTime timestamp;
  final Map<String, List<String>> positiveSelections;
  final Map<String, List<String>> negativeSelections;
  final Map<String, String> customFeedback;
  final int? overallRating;
  final String? additionalComments;

  const StageFeedback({
    required this.id,
    required this.stage,
    required this.flightId,
    required this.pnr,
    required this.timestamp,
    required this.positiveSelections,
    required this.negativeSelections,
    required this.customFeedback,
    this.overallRating,
    this.additionalComments,
  });

  factory StageFeedback.fromJson(Map<String, dynamic> json) {
    return StageFeedback(
      id: json['id'],
      stage: FeedbackStage.values.firstWhere(
        (e) => e.toString() == 'FeedbackStage.${json['stage']}',
      ),
      flightId: json['flightId'],
      pnr: json['pnr'],
      timestamp: DateTime.parse(json['timestamp']),
      positiveSelections: Map<String, List<String>>.from(
        json['positiveSelections']?.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ) ?? {},
      ),
      negativeSelections: Map<String, List<String>>.from(
        json['negativeSelections']?.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ) ?? {},
      ),
      customFeedback: Map<String, String>.from(json['customFeedback'] ?? {}),
      overallRating: json['overallRating'],
      additionalComments: json['additionalComments'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stage': stage.toString().split('.').last,
      'flightId': flightId,
      'pnr': pnr,
      'timestamp': timestamp.toIso8601String(),
      'positiveSelections': positiveSelections,
      'negativeSelections': negativeSelections,
      'customFeedback': customFeedback,
      'overallRating': overallRating,
      'additionalComments': additionalComments,
    };
  }

  StageFeedback copyWith({
    String? id,
    FeedbackStage? stage,
    String? flightId,
    String? pnr,
    DateTime? timestamp,
    Map<String, List<String>>? positiveSelections,
    Map<String, List<String>>? negativeSelections,
    Map<String, String>? customFeedback,
    int? overallRating,
    String? additionalComments,
  }) {
    return StageFeedback(
      id: id ?? this.id,
      stage: stage ?? this.stage,
      flightId: flightId ?? this.flightId,
      pnr: pnr ?? this.pnr,
      timestamp: timestamp ?? this.timestamp,
      positiveSelections: positiveSelections ?? this.positiveSelections,
      negativeSelections: negativeSelections ?? this.negativeSelections,
      customFeedback: customFeedback ?? this.customFeedback,
      overallRating: overallRating ?? this.overallRating,
      additionalComments: additionalComments ?? this.additionalComments,
    );
  }
}

class StageQuestion {
  final String id;
  final String title;
  final String subtitle;
  final FeedbackType type;
  final List<FeedbackOption> options;
  final bool isRequired;
  final bool allowMultiple;

  const StageQuestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.options,
    this.isRequired = true,
    this.allowMultiple = true,
  });

  factory StageQuestion.fromJson(Map<String, dynamic> json) {
    return StageQuestion(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      type: FeedbackType.values.firstWhere(
        (e) => e.toString() == 'FeedbackType.${json['type']}',
      ),
      options: (json['options'] as List)
          .map((option) => FeedbackOption.fromJson(option))
          .toList(),
      isRequired: json['isRequired'] ?? true,
      allowMultiple: json['allowMultiple'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type.toString().split('.').last,
      'options': options.map((option) => option.toJson()).toList(),
      'isRequired': isRequired,
      'allowMultiple': allowMultiple,
    };
  }
}

/// Model for journey events displayed in My Journey screen
class JourneyEvent {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final bool hasFeedback;
  final bool isCompleted;
  final FeedbackStage? feedbackType;

  JourneyEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.hasFeedback,
    required this.isCompleted,
    this.feedbackType,
  });
}
