class BoardingPass {
  final String id;
  final String name;
  final String pnr;
  final String airlineName;
  final String departureAirportCode;
  final String departureCity;
  final String departureCountryCode;
  final String departureTime;
  final String arrivalAirportCode;
  final String arrivalCity;
  final String arrivalCountryCode;
  final String arrivalTime;
  final String classOfTravel;
  final String airlineCode;
  final String flightNumber;
  final String visitStatus;
  final bool isReviewed;


  BoardingPass({
    this.id = '',
    this.name = '',
    this.pnr = '',
    this.airlineName = '',
    this.departureAirportCode = '',
    this.departureCity = '',
    this.departureCountryCode = '',
    this.departureTime = '',
    this.arrivalAirportCode = '',
    this.arrivalCity = '',
    this.arrivalCountryCode = '',
    this.arrivalTime = '',
    this.classOfTravel = '',
    this.airlineCode = '',
    this.flightNumber = '',
    this.visitStatus = '',
    this.isReviewed = false,

  });

  BoardingPass copyWith({
    String? id,
    String? name,
    String? pnr,
    String? airlineName,
    String? departureAirportCode,
    String? departureCity,
    String? departureCountryCode,
    String? departureTime,
    String? arrivalAirportCode,
    String? arrivalCity,
    String? arrivalCountryCode,
    String? arrivalTime,
    String? classOfTravel,
    String? airlineCode,
    String? flightNumber,
    String? visitStatus,
    bool? isReviewed,
  
  }) {
    return BoardingPass(
      id: id ?? this.id,
      name: name ?? this.name,
      pnr: pnr ?? this.pnr,
      airlineName: airlineName ?? this.airlineName,
      departureAirportCode: departureAirportCode ?? this.departureAirportCode,
      departureCity: departureCity ?? this.departureCity,
      departureCountryCode: departureCountryCode ?? this.departureCountryCode,
      departureTime: departureTime ?? this.departureTime,
      arrivalAirportCode: arrivalAirportCode ?? this.arrivalAirportCode,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      arrivalCountryCode: arrivalCountryCode ?? this.arrivalCountryCode,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      classOfTravel: classOfTravel ?? this.classOfTravel,
      airlineCode: airlineCode ?? this.airlineCode,
      flightNumber: flightNumber ?? this.flightNumber,
      visitStatus: visitStatus ?? this.visitStatus,
      isReviewed: isReviewed ?? this.isReviewed,
   
    );
  }

  factory BoardingPass.fromJson(Map<String, dynamic> json) {
    return BoardingPass(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      pnr: json['pnr'] ?? '',
      airlineName: json['airlineName'] ?? '',
      departureAirportCode: json['departureAirportCode'] ?? '',
      departureCity: json['departureCity'] ?? '',
      departureCountryCode: json['departureCountryCode'] ?? '',
      departureTime: json['departureTime'] ?? '',
      arrivalAirportCode: json['arrivalAirportCode'] ?? '',
      arrivalCity: json['arrivalCity'] ?? '',
      arrivalCountryCode: json['arrivalCountryCode'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      classOfTravel: json['classOfTravel'] ?? '',
      airlineCode: json['airlineCode'] ?? '',
      flightNumber: json['flightNumber'] ?? '',
      visitStatus: json['visitStatus'] ?? '',
      isReviewed: json['isReviewed'] ?? false,
 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'pnr': pnr,
      'airlineName': airlineName,
      'departureAirportCode': departureAirportCode,
      'departureCity': departureCity,
      'departureCountryCode': departureCountryCode,
      'departureTime': departureTime,
      'arrivalAirportCode': arrivalAirportCode,
      'arrivalCity': arrivalCity,
      'arrivalCountryCode': arrivalCountryCode,
      'arrivalTime': arrivalTime,
      'classOfTravel': classOfTravel,
      'airlineCode': airlineCode,
      'flightNumber': flightNumber,
      'visitStatus': visitStatus,
      'isReviewed': isReviewed,
   
    };
  }
}