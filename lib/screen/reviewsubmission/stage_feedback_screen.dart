import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stage_feedback_model.dart';
import '../../services/stage_question_service.dart';
import '../../utils/app_styles.dart';
import '../../provider/stage_feedback_provider.dart';
import '../app_widgets/main_button.dart';

class StageFeedbackScreen extends ConsumerStatefulWidget {
  final FeedbackStage stage;
  final String flightId;
  final String pnr;

  const StageFeedbackScreen({
    Key? key,
    required this.stage,
    required this.flightId,
    required this.pnr,
  }) : super(key: key);

  @override
  ConsumerState<StageFeedbackScreen> createState() => _StageFeedbackScreenState();
}

class _StageFeedbackScreenState extends ConsumerState<StageFeedbackScreen> {
  final Map<String, List<String>> _positiveSelections = {};
  final Map<String, List<String>> _negativeSelections = {};
  final Map<String, String> _customFeedback = {};
  int? _overallRating;
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _customTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _customTextController.dispose();
    super.dispose();
  }

  void _toggleSelection(String questionId, String optionId, FeedbackType type) {
    setState(() {
      final selections = type == FeedbackType.positive 
          ? _positiveSelections 
          : _negativeSelections;
      
      if (!selections.containsKey(questionId)) {
        selections[questionId] = [];
      }
      
      if (selections[questionId]!.contains(optionId)) {
        selections[questionId]!.remove(optionId);
        if (selections[questionId]!.isEmpty) {
          selections.remove(questionId);
        }
      } else {
        selections[questionId]!.add(optionId);
      }
    });
  }

  void _showCustomFeedbackDialog(String questionId, String optionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tell us more'),
        content: TextField(
          controller: _customTextController,
          decoration: InputDecoration(
            hintText: 'Please describe...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_customTextController.text.isNotEmpty) {
                setState(() {
                  _customFeedback['${questionId}_$optionId'] = _customTextController.text;
                });
                _customTextController.clear();
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _submitFeedback() {
    final feedback = StageFeedback(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      stage: widget.stage,
      flightId: widget.flightId,
      pnr: widget.pnr,
      timestamp: DateTime.now(),
      positiveSelections: _positiveSelections,
      negativeSelections: _negativeSelections,
      customFeedback: _customFeedback,
      overallRating: _overallRating,
      additionalComments: _commentsController.text.isNotEmpty 
          ? _commentsController.text 
          : null,
    );

    // Store feedback locally - will be submitted with complete review
    ref.read(stageFeedbackProvider.notifier).addFeedback(widget.flightId, feedback);
    debugPrint('✅ Stage feedback saved locally: ${feedback.stage}');
    
    // Show success message and navigate back
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you for your feedback! We\'ll include this in your final review.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final questions = StageQuestionService.getQuestionsForStage(widget.stage);
    final stageTitle = StageQuestionService.getStageTitle(widget.stage);
    final stageSubtitle = StageQuestionService.getStageSubtitle(widget.stage);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          stageTitle,
          style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with illustration placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getStageIcon(widget.stage),
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Flight Experience',
                      style: AppStyles.textStyle_16_600.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Main question
            Text(
              'How was the ${_getStageContext(widget.stage)}?',
              style: AppStyles.textStyle_24_600.copyWith(color: Colors.black),
            ),
            
            SizedBox(height: 8),
            
            Text(
              stageSubtitle,
              style: AppStyles.textStyle_14_400.copyWith(color: Colors.grey[600]),
            ),
            
            SizedBox(height: 16),
            
            // Star rating
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _overallRating = index + 1;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    child: Icon(
                      index < (_overallRating ?? 0) ? Icons.star : Icons.star_border,
                      color: index < (_overallRating ?? 0) ? Colors.amber : Colors.grey[400],
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            
            SizedBox(height: 32),
            
            // Questions
            ...questions.map((question) => _buildQuestionSection(question)),
            
            SizedBox(height: 24),
            
            // Additional comments
            Text(
              'Additional comments (optional)',
              style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
            ),
            
            SizedBox(height: 8),
            
            TextField(
              controller: _commentsController,
              decoration: InputDecoration(
                hintText: 'Tell us anything else about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
              maxLines: 3,
            ),
            
            SizedBox(height: 32),
            
            // Submit button
            MainButton(
              text: 'Submit Feedback',
              onPressed: _canSubmit() ? _submitFeedback : null,
              color: _canSubmit() ? Color(0xFF3B82F6) : Colors.grey[400]!,
            ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSection(StageQuestion question) {
    return Container(
      margin: EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.title,
            style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
          ),
          
          SizedBox(height: 8),
          
          Text(
            question.subtitle,
            style: AppStyles.textStyle_14_400.copyWith(color: Colors.grey[600]),
          ),
          
          SizedBox(height: 16),
          
          // Bubble options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: question.options.map((option) {
              final isSelected = _isOptionSelected(question.id, option.id, question.type);
              
              return GestureDetector(
                onTap: () {
                  if (option.isCustom) {
                    _showCustomFeedbackDialog(question.id, option.id);
                  } else {
                    _toggleSelection(question.id, option.id, question.type);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (question.type == FeedbackType.positive ? Colors.green[50] : Colors.red[50])
                        : Colors.grey[100],
                    border: Border.all(
                      color: isSelected 
                          ? (question.type == FeedbackType.positive ? Colors.green : Colors.red)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    option.text,
                    style: AppStyles.textStyle_14_500.copyWith(
                      color: isSelected 
                          ? (question.type == FeedbackType.positive ? Colors.green[800] : Colors.red[800])
                          : Colors.grey[700],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Show custom feedback if any
          if (_customFeedback.containsKey('${question.id}_something_else'))
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _customFeedback['${question.id}_something_else']!,
                style: AppStyles.textStyle_14_400.copyWith(color: Colors.blue[800]),
              ),
            ),
        ],
      ),
    );
  }

  bool _isOptionSelected(String questionId, String optionId, FeedbackType type) {
    final selections = type == FeedbackType.positive 
        ? _positiveSelections 
        : _negativeSelections;
    
    return selections[questionId]?.contains(optionId) ?? false;
  }

  bool _canSubmit() {
    return _overallRating != null && 
           (_positiveSelections.isNotEmpty || _negativeSelections.isNotEmpty);
  }

  IconData _getStageIcon(FeedbackStage stage) {
    switch (stage) {
      case FeedbackStage.preFlight:
        return Icons.flight_takeoff;
      case FeedbackStage.inFlight:
        return Icons.flight;
      case FeedbackStage.postFlight:
        return Icons.flight_land;
      default:
        return Icons.flight;
    }
  }

  String _getStageContext(FeedbackStage stage) {
    switch (stage) {
      case FeedbackStage.preFlight:
        return 'airport';
      case FeedbackStage.inFlight:
        return 'flight';
      case FeedbackStage.postFlight:
        return 'journey';
      default:
        return 'experience';
    }
  }
}