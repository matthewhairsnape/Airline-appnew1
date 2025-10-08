class AirlineReviewModel {
  final String reviewer;
  final String from;
  final String to;
  final String? airline;
  final String classTravel;
  final Map<String, dynamic> departureArrival;
  final Map<String, dynamic> comfort;
  final Map<String, dynamic> cleanliness;
  final Map<String, dynamic> onboardService;
  final Map<String, dynamic> foodBeverage;
  final Map<String, dynamic> entertainmentWifi;
  final String comment;
  List<dynamic>? imageUrls;

  AirlineReviewModel({
    required this.reviewer,
    required this.from,
    required this.to,
    this.airline,
    required this.classTravel,
    required this.departureArrival,
    required this.comfort,
    required this.cleanliness,
    required this.onboardService,
    required this.foodBeverage,
    required this.entertainmentWifi,
    required this.comment,
    this.imageUrls,
  });

  Map<String, dynamic> toJson() {
    return {
      'reviewer': reviewer,
      'from': from,
      'to': to,
      'airline': airline,
      'classTravel': classTravel,
      'departureArrival': departureArrival,
      'comfort': comfort,
      'cleanliness': cleanliness,
      'onboardService': onboardService,
      'foodBeverage': foodBeverage,
      'entertainmentWifi': entertainmentWifi,
      'comment': comment,
      'imageUrls': imageUrls,
    };
  }

  factory AirlineReviewModel.fromJson(Map<String, dynamic> json) {
    return AirlineReviewModel(
      reviewer: json['reviewer'],
      from: json['from'],
      to: json['to'],
      airline: json['airline'],
      classTravel: json['classTravel'],
      departureArrival: json['departureArrival'],
      comfort: json['comfort'],
      cleanliness: json['cleanliness'],
      onboardService: json['onboardService'],
      foodBeverage: json['foodBeverage'],
      entertainmentWifi: json['entertainmentWifi'],
      comment: json['comment'],
      imageUrls: List<String>.from(json['imageUrls']),
    );
  }
}