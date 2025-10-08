import 'package:airline_app/models/flight_tracking_model.dart';

/// Service to manage stage-specific questions based on flight phase
class StageQuestionService {
  /// Get questions for a specific flight phase
  static List<StageQuestion> getQuestionsForPhase(FlightPhase phase) {
    switch (phase) {
      case FlightPhase.checkInOpen:
        return _checkInQuestions;
      case FlightPhase.boarding:
        return _boardingQuestions;
      case FlightPhase.inFlight:
        return _inFlightQuestions;
      case FlightPhase.landed:
      case FlightPhase.baggageClaim:
        return _postFlightQuestions;
      default:
        return [];
    }
  }

  /// Questions for check-in phase
  static final List<StageQuestion> _checkInQuestions = [
    StageQuestion(
      id: 'checkin_experience',
      phase: FlightPhase.checkInOpen,
      question: 'How was your check-in experience?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor'],
      category: 'Check-In',
      priority: 1,
    ),
    StageQuestion(
      id: 'checkin_time',
      phase: FlightPhase.checkInOpen,
      question: 'How long did check-in take?',
      options: ['Under 5 min', '5-10 min', '10-20 min', '20-30 min', 'Over 30 min'],
      category: 'Check-In',
      priority: 2,
    ),
    StageQuestion(
      id: 'checkin_staff',
      phase: FlightPhase.checkInOpen,
      question: 'How helpful was the check-in staff?',
      options: ['Very helpful', 'Helpful', 'Neutral', 'Unhelpful', 'Very unhelpful'],
      category: 'Check-In',
      priority: 3,
    ),
    StageQuestion(
      id: 'bag_drop',
      phase: FlightPhase.checkInOpen,
      question: 'How was the bag drop process?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor', 'N/A'],
      category: 'Check-In',
      priority: 4,
    ),
  ];

  /// Questions for boarding phase
  static final List<StageQuestion> _boardingQuestions = [
    StageQuestion(
      id: 'boarding_process',
      phase: FlightPhase.boarding,
      question: 'How organized was the boarding process?',
      options: ['Very organized', 'Organized', 'Somewhat organized', 'Disorganized', 'Very disorganized'],
      category: 'Boarding',
      priority: 1,
    ),
    StageQuestion(
      id: 'boarding_time',
      phase: FlightPhase.boarding,
      question: 'How long did boarding take?',
      options: ['Very quick', 'Quick', 'Average', 'Slow', 'Very slow'],
      category: 'Boarding',
      priority: 2,
    ),
    StageQuestion(
      id: 'gate_staff',
      phase: FlightPhase.boarding,
      question: 'How was the gate staff?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor'],
      category: 'Boarding',
      priority: 3,
    ),
    StageQuestion(
      id: 'boarding_announcement',
      phase: FlightPhase.boarding,
      question: 'Were boarding announcements clear?',
      options: ['Very clear', 'Clear', 'Somewhat clear', 'Unclear', 'Very unclear'],
      category: 'Boarding',
      priority: 4,
    ),
  ];

  /// Questions for in-flight phase
  static final List<StageQuestion> _inFlightQuestions = [
    StageQuestion(
      id: 'cabin_crew',
      phase: FlightPhase.inFlight,
      question: 'How was the cabin crew service?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor'],
      category: 'In-Flight Service',
      priority: 1,
    ),
    StageQuestion(
      id: 'seat_comfort',
      phase: FlightPhase.inFlight,
      question: 'How comfortable was your seat?',
      options: ['Very comfortable', 'Comfortable', 'Average', 'Uncomfortable', 'Very uncomfortable'],
      category: 'In-Flight Comfort',
      priority: 2,
    ),
    StageQuestion(
      id: 'meal_service',
      phase: FlightPhase.inFlight,
      question: 'How was the meal service?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor', 'N/A'],
      category: 'In-Flight Service',
      priority: 3,
    ),
    StageQuestion(
      id: 'wifi_quality',
      phase: FlightPhase.inFlight,
      question: 'How was the Wi-Fi quality?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor', 'Not used'],
      category: 'In-Flight Entertainment',
      priority: 4,
    ),
    StageQuestion(
      id: 'entertainment',
      phase: FlightPhase.inFlight,
      question: 'How was the entertainment system?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor', 'Not used'],
      category: 'In-Flight Entertainment',
      priority: 5,
    ),
    StageQuestion(
      id: 'cabin_cleanliness',
      phase: FlightPhase.inFlight,
      question: 'How clean was the cabin?',
      options: ['Very clean', 'Clean', 'Average', 'Dirty', 'Very dirty'],
      category: 'In-Flight Comfort',
      priority: 6,
    ),
  ];

  /// Questions for post-flight phase
  static final List<StageQuestion> _postFlightQuestions = [
    StageQuestion(
      id: 'landing_smoothness',
      phase: FlightPhase.landed,
      question: 'How smooth was the landing?',
      options: ['Very smooth', 'Smooth', 'Average', 'Rough', 'Very rough'],
      category: 'Arrival',
      priority: 1,
    ),
    StageQuestion(
      id: 'deplaning',
      phase: FlightPhase.landed,
      question: 'How was the deplaning process?',
      options: ['Very quick', 'Quick', 'Average', 'Slow', 'Very slow'],
      category: 'Arrival',
      priority: 2,
    ),
    StageQuestion(
      id: 'baggage_delivery',
      phase: FlightPhase.baggageClaim,
      question: 'How long did baggage delivery take?',
      options: ['Under 10 min', '10-20 min', '20-30 min', '30-45 min', 'Over 45 min', 'N/A'],
      category: 'Baggage',
      priority: 3,
    ),
    StageQuestion(
      id: 'baggage_condition',
      phase: FlightPhase.baggageClaim,
      question: 'What was the condition of your baggage?',
      options: ['Perfect', 'Good', 'Minor damage', 'Damaged', 'Lost', 'N/A'],
      category: 'Baggage',
      priority: 4,
    ),
    StageQuestion(
      id: 'overall_flight',
      phase: FlightPhase.landed,
      question: 'How was your overall flight experience?',
      options: ['Excellent', 'Good', 'Average', 'Poor', 'Very Poor'],
      category: 'Overall',
      priority: 5,
    ),
  ];

  /// Get notification message for a flight phase
  static String getNotificationMessage(FlightPhase phase) {
    switch (phase) {
      case FlightPhase.checkInOpen:
        return '✈️ Your flight check-in is open! Share your check-in experience with us.';
      case FlightPhase.boarding:
        return '🎫 Boarding has started! How\'s your boarding experience so far?';
      case FlightPhase.inFlight:
        return '☁️ You\'re in the air! Quick question about your in-flight experience.';
      case FlightPhase.landed:
        return '🛬 Welcome! You\'ve landed. Tell us about your flight.';
      case FlightPhase.baggageClaim:
        return '🧳 At baggage claim? Let us know about your baggage experience.';
      default:
        return '✈️ Share your experience with us!';
    }
  }

  /// Get notification title for a flight phase
  static String getNotificationTitle(FlightPhase phase) {
    switch (phase) {
      case FlightPhase.checkInOpen:
        return 'Check-in Feedback';
      case FlightPhase.boarding:
        return 'Boarding Feedback';
      case FlightPhase.inFlight:
        return 'In-Flight Feedback';
      case FlightPhase.landed:
        return 'Arrival Feedback';
      case FlightPhase.baggageClaim:
        return 'Baggage Feedback';
      default:
        return 'Flight Feedback';
    }
  }

  /// Determine if a phase should trigger a notification
  static bool shouldNotifyForPhase(FlightPhase phase) {
    return [
      FlightPhase.checkInOpen,
      FlightPhase.boarding,
      FlightPhase.inFlight,
      FlightPhase.landed,
      FlightPhase.baggageClaim,
    ].contains(phase);
  }
}

