import 'package:flutter/material.dart';
import '../models/flight_tracking_model.dart';
import '../models/stage_feedback_model.dart';

class StageQuestionService {
  static const Map<FeedbackStage, List<StageQuestion>> _stageQuestions = {
    FeedbackStage.preFlight: [
      StageQuestion(
        id: 'preflight_positive',
        title: '👍 What stands out?',
        subtitle: 'Select what you liked about your pre-flight experience',
        type: FeedbackType.positive,
        options: [
          FeedbackOption(id: 'checkin_process', text: 'Check-in process'),
          FeedbackOption(id: 'security_wait', text: 'Airport Security line wait time'),
          FeedbackOption(id: 'boarding_process', text: 'Boarding process'),
          FeedbackOption(id: 'airport_facilities', text: 'Airport Facilities and Shops'),
          FeedbackOption(id: 'smooth_experience', text: 'Smooth Airport experience'),
          FeedbackOption(id: 'airline_lounge', text: 'Airline Lounge'),
          FeedbackOption(id: 'something_else', text: 'Something else', isCustom: true),
        ],
      ),
      StageQuestion(
        id: 'preflight_negative',
        title: '👎 What could be improved?',
        subtitle: 'Select what could be better about your pre-flight experience',
        type: FeedbackType.negative,
        options: [
          FeedbackOption(id: 'checkin_process', text: 'Check-in process'),
          FeedbackOption(id: 'security_wait', text: 'Security line wait time'),
          FeedbackOption(id: 'boarding_process', text: 'Boarding process'),
          FeedbackOption(id: 'airport_facilities', text: 'Airport Facilities and Shops'),
          FeedbackOption(id: 'smooth_experience', text: 'Smooth Airport experience'),
          FeedbackOption(id: 'airline_lounge', text: 'Airline Lounge'),
          FeedbackOption(id: 'something_else', text: 'Something else', isCustom: true),
        ],
      ),
    ],
    FeedbackStage.inFlight: [
      StageQuestion(
        id: 'inflight_positive',
        title: '👍 What stands out?',
        subtitle: 'Select what you liked about your in-flight experience',
        type: FeedbackType.positive,
        options: [
          FeedbackOption(id: 'seat_comfort', text: 'Seat comfort'),
          FeedbackOption(id: 'cabin_cleanliness', text: 'Cabin cleanliness'),
          FeedbackOption(id: 'cabin_crew', text: 'Cabin crew'),
          FeedbackOption(id: 'entertainment', text: 'In-flight entertainment'),
          FeedbackOption(id: 'wifi', text: 'Wi-Fi'),
          FeedbackOption(id: 'food_beverage', text: 'Food and beverage'),
          FeedbackOption(id: 'something_else', text: 'Something else', isCustom: true),
        ],
      ),
      StageQuestion(
        id: 'inflight_negative',
        title: '👎 What could be improved?',
        subtitle: 'Select what could be better about your in-flight experience',
        type: FeedbackType.negative,
        options: [
          FeedbackOption(id: 'seat_comfort', text: 'Seat comfort'),
          FeedbackOption(id: 'cabin_cleanliness', text: 'Cabin cleanliness'),
          FeedbackOption(id: 'cabin_crew', text: 'Cabin crew'),
          FeedbackOption(id: 'entertainment', text: 'In-flight entertainment'),
          FeedbackOption(id: 'wifi', text: 'Wi-Fi'),
          FeedbackOption(id: 'food_beverage', text: 'Food and beverage'),
          FeedbackOption(id: 'something_else', text: 'Something else', isCustom: true),
        ],
      ),
    ],
    FeedbackStage.postFlight: [
      StageQuestion(
        id: 'postflight_positive',
        title: '👍 What stands out?',
        subtitle: 'Select what you liked about your overall journey',
        type: FeedbackType.positive,
        options: [
          FeedbackOption(id: 'friendly_service', text: 'Friendly and helpful service'),
          FeedbackOption(id: 'smooth_flight', text: 'Smooth and trouble-free flight'),
          FeedbackOption(id: 'onboard_comfort', text: 'Onboard Comfort'),
          FeedbackOption(id: 'food_beverage', text: 'Food and Beverage'),
          FeedbackOption(id: 'wifi_ife', text: 'Wi-Fi and IFE'),
          FeedbackOption(id: 'communication', text: 'Communication from airline'),
          FeedbackOption(id: 'baggage_connection', text: 'Baggage delivery or ease of connection'),
          FeedbackOption(id: 'something_else', text: 'Something else', isCustom: true),
        ],
      ),
      StageQuestion(
        id: 'postflight_negative',
        title: '👎 What could be improved?',
        subtitle: 'Select what could be better about your overall journey',
        type: FeedbackType.negative,
        options: [
          FeedbackOption(id: 'friendly_service', text: 'Friendly and helpful service'),
          FeedbackOption(id: 'stressful_flight', text: 'Stressful and uneasy flight'),
          FeedbackOption(id: 'onboard_comfort', text: 'Onboard Comfort'),
          FeedbackOption(id: 'food_beverage', text: 'Food and Beverage'),
          FeedbackOption(id: 'wifi_ife', text: 'Wi-Fi and IFE'),
          FeedbackOption(id: 'communication', text: 'Communication from airline'),
          FeedbackOption(id: 'baggage_connection', text: 'Baggage delivery or ease of connection'),
          FeedbackOption(id: 'something_else', text: 'Something else', isCustom: true),
        ],
      ),
    ],
  };

  static List<StageQuestion> getQuestionsForStage(FeedbackStage stage) {
    return _stageQuestions[stage] ?? [];
  }

  static String getStageTitle(FeedbackStage stage) {
    switch (stage) {
      case FeedbackStage.preFlight:
        return 'Preflight Experience';
      case FeedbackStage.inFlight:
        return 'In-Flight Experience';
      case FeedbackStage.postFlight:
        return 'Overall Journey Reflection';
      default:
        return 'Flight Experience';
    }
  }

  static String getStageSubtitle(FeedbackStage stage) {
    switch (stage) {
      case FeedbackStage.preFlight:
        return 'Tell us about your airport experience before boarding';
      case FeedbackStage.inFlight:
        return 'Share your in-flight experience';
      case FeedbackStage.postFlight:
        return 'Reflect on your overall journey';
      default:
        return 'Share your experience';
    }
  }

  static FeedbackStage getStageFromFlightPhase(FlightPhase phase) {
    switch (phase) {
      case FlightPhase.checkInOpen:
      case FlightPhase.security:
      case FlightPhase.boarding:
        return FeedbackStage.preFlight;
      case FlightPhase.inFlight:
        return FeedbackStage.inFlight;
      case FlightPhase.landed:
      case FlightPhase.baggageClaim:
        return FeedbackStage.postFlight;
      default:
        return FeedbackStage.preFlight;
    }
  }

  static String getNotificationMessage(FeedbackStage stage) {
    switch (stage) {
      case FeedbackStage.preFlight:
        return '✈️ Your flight check-in is open! Share your pre-flight experience with us.';
      case FeedbackStage.inFlight:
        return '☁️ You\'re in the air! Quick question about your in-flight experience.';
      case FeedbackStage.postFlight:
        return '🛬 Welcome! You\'ve landed. Tell us about your overall journey.';
      default:
        return '✈️ Share your experience with us!';
    }
  }

  static String getNotificationTitle(FeedbackStage stage) {
    switch (stage) {
      case FeedbackStage.preFlight:
        return 'Preflight Feedback';
      case FeedbackStage.inFlight:
        return 'In-Flight Feedback';
      case FeedbackStage.postFlight:
        return 'Journey Reflection';
      default:
        return 'Flight Feedback';
    }
  }

  static bool shouldNotifyForStage(FeedbackStage stage) {
    return true; // All stages should trigger notifications
  }
}