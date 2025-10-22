class AirportReviewModel {
  final String reviewer;
  final String airline;
  final String airport;
  final String classTravel;
  final Map<String, dynamic> accessibility;
  final Map<String, dynamic> waitTimes;
  final Map<String, dynamic> helpfulness;
  final Map<String, dynamic> ambienceComfort;
  final Map<String, dynamic> foodBeverage;
  final Map<String, dynamic> amenities;
  final String comment;
  List<dynamic>? imageUrls;

  AirportReviewModel({
    required this.reviewer,
    required this.airline,
    required this.airport,
    required this.classTravel,
    required this.accessibility,
    required this.waitTimes,
    required this.helpfulness,
    required this.ambienceComfort,
    required this.foodBeverage,
    required this.amenities,
    required this.comment,
    this.imageUrls,
  });

  Map<String, dynamic> toJson() {
    return {
      'reviewer': reviewer,
      'airline': airline,
      'airport': airport,
      'classTravel': classTravel,
      'accessibility': accessibility,
      'waitTimes': waitTimes,
      'helpfulness': helpfulness,
      'ambienceComfort': ambienceComfort,
      'foodBeverage': foodBeverage,
      'amenities': amenities,
      'comment': comment,
      'imageUrls': imageUrls,
    };
  }

  factory AirportReviewModel.fromJson(Map<String, dynamic> json) {
    return AirportReviewModel(
      reviewer: json['reviewer'],
      airline: json['airline'],
      airport: json['airport'],
      classTravel: json['classTravel'],
      accessibility: json['accessibility'],
      waitTimes: json['waitTimes'],
      helpfulness: json['helpfulness'],
      ambienceComfort: json['ambienceComfort'],
      foodBeverage: json['foodBeverage'],
      amenities: json['amenities'],
      comment: json['comment'],
      imageUrls: List<String>.from(json['imageUrls']),
    );
  }
}
