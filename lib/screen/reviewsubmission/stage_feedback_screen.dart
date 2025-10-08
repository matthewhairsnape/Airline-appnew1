import 'package:airline_app/models/flight_tracking_model.dart';
import 'package:airline_app/provider/flight_tracking_provider.dart';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/services/stage_question_service.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for collecting stage-specific feedback during flight phases
class StageFeedbackScreen extends ConsumerStatefulWidget {
  final String pnr;
  final FlightPhase phase;

  const StageFeedbackScreen({
    super.key,
    required this.pnr,
    required this.phase,
  });

  @override
  ConsumerState<StageFeedbackScreen> createState() => _StageFeedbackScreenState();
}

class _StageFeedbackScreenState extends ConsumerState<StageFeedbackScreen> {
  final Map<String, String> _responses = {};
  int _currentQuestionIndex = 0;
  List<StageQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _questions = StageQuestionService.getQuestionsForPhase(widget.phase);
  }

  void _handleOptionSelected(String questionId, String option) {
    setState(() {
      _responses[questionId] = option;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitFeedback() async {
    // Get flight info
    final flight = ref.read(flightTrackingProvider.notifier).getFlight(widget.pnr);

    if (flight == null) return;

    // Create operational context from Cirium data
    final operationalContext = {
      'flightId': flight.flightId,
      'carrier': flight.carrier,
      'flightNumber': flight.flightNumber,
      'departureAirport': flight.departureAirport,
      'arrivalAirport': flight.arrivalAirport,
      'departureTime': flight.departureTime.toIso8601String(),
      'arrivalTime': flight.arrivalTime.toIso8601String(),
      'currentPhase': widget.phase.toString(),
      'phaseStartTime': flight.phaseStartTime?.toIso8601String(),
      'events': flight.events.map((e) => e.toJson()).toList(),
      'ciriumVerified': flight.isVerified,
    };

    // Create feedback object
    final stageFeedback = StageFeedback(
      id: '${widget.pnr}_${widget.phase}_${DateTime.now().millisecondsSinceEpoch}',
      flightId: flight.flightId,
      userId: '', // Get from user provider
      phase: widget.phase,
      responses: _responses,
      timestamp: DateTime.now(),
      operationalContext: operationalContext,
    );

    debugPrint('📝 Stage feedback submitted:');
    debugPrint('   Phase: ${widget.phase}');
    debugPrint('   Responses: $_responses');
    debugPrint('   Operational context: $operationalContext');

    // TODO: Send feedback to backend API
    // await feedbackService.submitStageFeedback(stageFeedback);
    debugPrint('Stage feedback ready to submit: ${stageFeedback.toJson()}');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _getPhaseTitle() {
    switch (widget.phase) {
      case FlightPhase.checkInOpen:
        return 'Check-In Feedback';
      case FlightPhase.boarding:
        return 'Boarding Feedback';
      case FlightPhase.inFlight:
        return 'In-Flight Feedback';
      case FlightPhase.landed:
      case FlightPhase.baggageClaim:
        return 'Arrival Feedback';
      default:
        return 'Flight Feedback';
    }
  }

  String _getPhaseEmoji() {
    switch (widget.phase) {
      case FlightPhase.checkInOpen:
        return '✅';
      case FlightPhase.boarding:
        return '🎫';
      case FlightPhase.inFlight:
        return '✈️';
      case FlightPhase.landed:
      case FlightPhase.baggageClaim:
        return '🛬';
      default:
        return '✈️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final flight = ref.watch(flightTrackingProvider).trackedFlights[widget.pnr];

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppbarWidget(
          title: _getPhaseTitle(),
          onBackPressed: () => Navigator.pop(context),
        ),
        body: Center(
          child: Text('No questions available for this phase'),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppbarWidget(
        title: _getPhaseTitle(),
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Flight info banner
          if (flight != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _getPhaseEmoji(),
                    style: TextStyle(fontSize: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${flight.carrier}${flight.flightNumber}',
                          style: AppStyles.textStyle_18_600.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${flight.departureAirport} → ${flight.arrivalAirport}',
                          style: AppStyles.textStyle_15_400.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Progress indicator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                      style: AppStyles.textStyle_15_400.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: AppStyles.textStyle_15_600.copyWith(
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ),
          ),

          // Question and options
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),
                  Text(
                    currentQuestion.question,
                    style: AppStyles.textStyle_24_600.copyWith(
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 32),
                  ...currentQuestion.options.map<Widget>((option) {
                    final isSelected = _responses[currentQuestion.id] == option;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _handleOptionSelected(currentQuestion.id, option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? Color(0xFF3B82F6) : Colors.white,
                            border: Border.all(
                              color: isSelected ? Color(0xFF3B82F6) : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(0xFF3B82F6).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  color: isSelected ? Colors.white : Colors.transparent,
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Color(0xFF3B82F6),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: AppStyles.textStyle_16_600.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? Colors.white : Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousQuestion,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Color(0xFF3B82F6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Previous',
                        style: AppStyles.textStyle_16_600.copyWith(
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                if (_currentQuestionIndex > 0) SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Opacity(
                    opacity: _responses.containsKey(currentQuestion.id) ? 1.0 : 0.5,
                    child: MainButton(
                      text: _currentQuestionIndex == _questions.length - 1
                          ? 'Submit Feedback'
                          : 'Next',
                      onPressed: () {
                        if (_responses.containsKey(currentQuestion.id)) {
                          if (_currentQuestionIndex == _questions.length - 1) {
                            _submitFeedback();
                          } else {
                            _nextQuestion();
                          }
                        }
                      },
                      color: _responses.containsKey(currentQuestion.id)
                          ? Color(0xFF3B82F6)
                          : Colors.grey[400]!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

