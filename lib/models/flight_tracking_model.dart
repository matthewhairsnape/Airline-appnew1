/// Model for tracking flight phases and status in real-time
class FlightTrackingModel {
  final String flightId;
  final String pnr;
  final String carrier;
  final String flightNumber;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String departureAirport;
  final String arrivalAirport;
  final FlightPhase currentPhase;
  final DateTime? phaseStartTime;
  final Map<String, dynamic> ciriumData;
  final List<FlightEvent> events;
  final bool isVerified;

  FlightTrackingModel({
    required this.flightId,
    required this.pnr,
    required this.carrier,
    required this.flightNumber,
    required this.departureTime,
    required this.arrivalTime,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.currentPhase,
    this.phaseStartTime,
    required this.ciriumData,
    this.events = const [],
    this.isVerified = false,
  });

  FlightTrackingModel copyWith({
    String? flightId,
    String? pnr,
    String? carrier,
    String? flightNumber,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? departureAirport,
    String? arrivalAirport,
    FlightPhase? currentPhase,
    DateTime? phaseStartTime,
    Map<String, dynamic>? ciriumData,
    List<FlightEvent>? events,
    bool? isVerified,
  }) {
    return FlightTrackingModel(
      flightId: flightId ?? this.flightId,
      pnr: pnr ?? this.pnr,
      carrier: carrier ?? this.carrier,
      flightNumber: flightNumber ?? this.flightNumber,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureAirport: departureAirport ?? this.departureAirport,
      arrivalAirport: arrivalAirport ?? this.arrivalAirport,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseStartTime: phaseStartTime ?? this.phaseStartTime,
      ciriumData: ciriumData ?? this.ciriumData,
      events: events ?? this.events,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  factory FlightTrackingModel.fromJson(Map<String, dynamic> json) {
    return FlightTrackingModel(
      flightId: json['flightId'] ?? '',
      pnr: json['pnr'] ?? '',
      carrier: json['carrier'] ?? '',
      flightNumber: json['flightNumber'] ?? '',
      departureTime: DateTime.parse(json['departureTime']),
      arrivalTime: DateTime.parse(json['arrivalTime']),
      departureAirport: json['departureAirport'] ?? '',
      arrivalAirport: json['arrivalAirport'] ?? '',
      currentPhase: FlightPhase.values.firstWhere(
        (e) => e.toString() == 'FlightPhase.${json['currentPhase']}',
        orElse: () => FlightPhase.preCheckIn,
      ),
      phaseStartTime: json['phaseStartTime'] != null
          ? DateTime.parse(json['phaseStartTime'])
          : null,
      ciriumData: json['ciriumData'] ?? {},
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => FlightEvent.fromJson(e))
              .toList() ??
          [],
      isVerified: json['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flightId': flightId,
      'pnr': pnr,
      'carrier': carrier,
      'flightNumber': flightNumber,
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'departureAirport': departureAirport,
      'arrivalAirport': arrivalAirport,
      'currentPhase': currentPhase.toString().split('.').last,
      'phaseStartTime': phaseStartTime?.toIso8601String(),
      'ciriumData': ciriumData,
      'events': events.map((e) => e.toJson()).toList(),
      'isVerified': isVerified,
    };
  }
}

/// Enum representing different flight phases
enum FlightPhase {
  preCheckIn, // Before check-in window opens
  checkInOpen, // Check-in is open
  boarding, // Boarding has started
  departed, // Flight has departed
  inFlight, // Flight is in the air
  landed, // Flight has landed
  baggageClaim, // At baggage claim
  completed, // Journey completed
}

/// Model for individual flight events tracked by Cirium
class FlightEvent {
  final String eventType;
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> metadata;

  FlightEvent({
    required this.eventType,
    required this.timestamp,
    required this.description,
    this.metadata = const {},
  });

  factory FlightEvent.fromJson(Map<String, dynamic> json) {
    return FlightEvent(
      eventType: json['eventType'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'] ?? '',
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'metadata': metadata,
    };
  }
}

/// Model for stage-specific questions
class StageQuestion {
  final String id;
  final FlightPhase phase;
  final String question;
  final List<String> options;
  final String category;
  final int priority;

  StageQuestion({
    required this.id,
    required this.phase,
    required this.question,
    required this.options,
    required this.category,
    this.priority = 0,
  });

  factory StageQuestion.fromJson(Map<String, dynamic> json) {
    return StageQuestion(
      id: json['id'] ?? '',
      phase: FlightPhase.values.firstWhere(
        (e) => e.toString() == 'FlightPhase.${json['phase']}',
        orElse: () => FlightPhase.preCheckIn,
      ),
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      category: json['category'] ?? '',
      priority: json['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phase': phase.toString().split('.').last,
      'question': question,
      'options': options,
      'category': category,
      'priority': priority,
    };
  }
}

/// Model for stage-specific feedback responses
class StageFeedback {
  final String id;
  final String flightId;
  final String userId;
  final FlightPhase phase;
  final Map<String, dynamic> responses;
  final DateTime timestamp;
  final Map<String, dynamic> operationalContext;

  StageFeedback({
    required this.id,
    required this.flightId,
    required this.userId,
    required this.phase,
    required this.responses,
    required this.timestamp,
    this.operationalContext = const {},
  });

  factory StageFeedback.fromJson(Map<String, dynamic> json) {
    return StageFeedback(
      id: json['id'] ?? '',
      flightId: json['flightId'] ?? '',
      userId: json['userId'] ?? '',
      phase: FlightPhase.values.firstWhere(
        (e) => e.toString() == 'FlightPhase.${json['phase']}',
        orElse: () => FlightPhase.preCheckIn,
      ),
      responses: json['responses'] ?? {},
      timestamp: DateTime.parse(json['timestamp']),
      operationalContext: json['operationalContext'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flightId': flightId,
      'userId': userId,
      'phase': phase.toString().split('.').last,
      'responses': responses,
      'timestamp': timestamp.toIso8601String(),
      'operationalContext': operationalContext,
    };
  }
}

