class LeaderboardCategory {
  final String tab;
  final String description;
  final List<String> sourceTags;
  final String formula;
  final String icon;
  final bool isTravelClass;
  final bool isAirportCategory; // New flag for airport categories

  const LeaderboardCategory({
    required this.tab,
    required this.description,
    required this.sourceTags,
    required this.formula,
    required this.icon,
    this.isTravelClass = false,
    this.isAirportCategory = false,
  });

  factory LeaderboardCategory.fromJson(Map<String, dynamic> json) {
    return LeaderboardCategory(
      tab: json['tab'],
      description: json['description'],
      sourceTags: List<String>.from(json['source_tags']),
      formula: json['formula'],
      icon: json['icon'],
      isTravelClass: json['is_travel_class'] ?? false,
      isAirportCategory: json['is_airport_category'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tab': tab,
      'description': description,
      'source_tags': sourceTags,
      'formula': formula,
      'icon': icon,
      'is_travel_class': isTravelClass,
      'is_airport_category': isAirportCategory,
    };
  }
}

class LeaderboardCategoryService {
  static const List<LeaderboardCategory> categories = [
    // All items are categories (swipeable tabs)
    LeaderboardCategory(
      tab: "First Class",
      description:
          "First class cabin rankings sourced directly from verified passenger scoring.",
      sourceTags: [
        "First Class",
        "First cabin",
        "Premium First",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "first",
      isTravelClass: false,
    ),
    LeaderboardCategory(
      tab: "Business Class",
      description:
          "Business cabin rankings sourced directly from verified passenger scoring.",
      sourceTags: [
        "Business Class",
        "Business cabin",
        "Premium cabin",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "business",
      isTravelClass: false,
    ),
    LeaderboardCategory(
      tab: "Premium Economy",
      description:
          "Premium Economy cabin rankings sourced directly from verified passenger scoring.",
      sourceTags: [
        "Premium Economy",
        "Premium Economy Class",
        "Economy Plus",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "premium",
      isTravelClass: false,
    ),
    LeaderboardCategory(
      tab: "Economy",
      description:
          "Economy cabin rankings sourced directly from verified passenger scoring.",
      sourceTags: [
        "Economy Class",
        "Economy",
        "Main cabin",
        "Coach",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "economy",
      isTravelClass: false,
    ),
    LeaderboardCategory(
      tab: "Airport Experience",
      description:
          "Measures satisfaction with airport facilities, check-in, security, boarding, and arrival processes.",
      sourceTags: [
        "Airport experience",
        "Departure experience",
        "Arrival experience",
        "Check-in process",
        "Security line wait time",
        "Boarding process",
        "Airport facilities",
        "Arrival process",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "airport",
    ),
    LeaderboardCategory(
      tab: "F&B",
      description: "Tracks satisfaction with meals and drinks onboard.",
      sourceTags: [
        "Good food",
        "Cold meal",
        "Poor quality beverage",
        "Food and beverage",
        "Food and Beverage",
        "F&B",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "restaurant",
    ),
    LeaderboardCategory(
      tab: "Seat Comfort",
      description:
          "Assesses passenger comfort and seat conditions during the flight.",
      sourceTags: [
        "Comfortable seat",
        "Uncomfortable seat",
        "Seat comfort",
        "Onboard Comfort",
        "Seat space",
        "Legroom",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "chair",
    ),
    LeaderboardCategory(
      tab: "IFE and Wifi",
      description:
          "Measures satisfaction with inflight entertainment and internet connectivity.",
      sourceTags: [
        "Inflight entertainment",
        "IFE",
        "Movies",
        "Onboard entertainment",
        "Seatback screen",
        "Good Wi-Fi",
        "Poor Wi-Fi",
        "Wi-Fi connectivity",
        "Wi-Fi and IFE",
        "Internet",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "wifi",
    ),
    LeaderboardCategory(
      tab: "Onboard Service",
      description:
          "Evaluates the helpfulness and service quality of the cabin crew and onboard service.",
      sourceTags: [
        "Crew helpful",
        "Friendly service",
        "Unfriendly crew",
        "Cabin crew",
        "Friendly and helpful service",
        "Onboard service",
        "Crew service",
        "Service quality",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "people",
    ),
    LeaderboardCategory(
      tab: "Cleanliness",
      description:
          "Scores how passengers perceive the cleanliness of cabins, restrooms, and touchpoints.",
      sourceTags: [
        "Cleanliness",
        "Cabin cleanliness",
        "Restroom cleanliness",
        "Sanitization",
        "Hygiene",
        "Aircraft cleanliness",
        "Clean cabin",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "cleaning",
    ),
    // Airport-specific categories for pre-flight feedback
    LeaderboardCategory(
      tab: "Check-in Process",
      description:
          "Measures satisfaction with airport check-in experience and efficiency.",
      sourceTags: [
        "Check-in process",
        "Check-in",
        "Check in",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "checkin",
      isAirportCategory: true,
    ),
    LeaderboardCategory(
      tab: "Security Wait Time",
      description:
          "Tracks passenger satisfaction with airport security line wait times.",
      sourceTags: [
        "Airport Security line wait time",
        "Security line wait time",
        "Security wait",
        "Security queue",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "security",
      isAirportCategory: true,
    ),
    LeaderboardCategory(
      tab: "Boarding Process",
      description:
          "Evaluates the efficiency and organization of the boarding process.",
      sourceTags: [
        "Boarding process",
        "Boarding",
        "Gate boarding",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "boarding",
      isAirportCategory: true,
    ),
    LeaderboardCategory(
      tab: "Airport Facilities",
      description:
          "Measures satisfaction with airport shops, restaurants, and amenities.",
      sourceTags: [
        "Airport Facilities and Shops",
        "Airport facilities",
        "Airport shops",
        "Airport amenities",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "shops",
      isAirportCategory: true,
    ),
    LeaderboardCategory(
      tab: "Smooth Experience",
      description:
          "Overall smoothness and ease of the airport experience.",
      sourceTags: [
        "Smooth Airport experience",
        "Smooth experience",
        "Easy airport",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "smooth",
      isAirportCategory: true,
    ),
    LeaderboardCategory(
      tab: "Airline Lounge",
      description:
          "Satisfaction with airline lounge facilities and services.",
      sourceTags: [
        "Airline Lounge",
        "Lounge",
        "Airport lounge",
      ],
      formula: "Positive Votes / (Positive + Negative Votes)",
      icon: "lounge",
      isAirportCategory: true,
    ),
  ];

  static List<LeaderboardCategory> getAllCategories() {
    return categories;
  }

  static List<LeaderboardCategory> getTravelClassCategories() {
    return categories.where((category) => category.isTravelClass).toList();
  }

  static List<LeaderboardCategory> getAirportCategories() {
    return categories.where((category) => category.isAirportCategory).toList();
  }

  static List<LeaderboardCategory> getPrimaryCategories() {
    return categories.where((category) => !category.isTravelClass && !category.isAirportCategory).toList();
  }

  static LeaderboardCategory getDefaultCategory() {
    final primaryCategories = getPrimaryCategories();
    return primaryCategories.isNotEmpty
        ? primaryCategories.first
        : categories.first;
  }

  static LeaderboardCategory getDefaultTravelClass() {
    final travelClasses = getTravelClassCategories();
    return travelClasses.isNotEmpty ? travelClasses.first : categories.first;
  }

  static LeaderboardCategory? getCategoryByTab(String tab) {
    try {
      return categories.firstWhere((category) => category.tab == tab);
    } catch (e) {
      return null;
    }
  }

  static List<String> getAllTabs() {
    return getPrimaryCategories().map((category) => category.tab).toList();
  }

  static List<String> getTravelClassTabs() {
    return getTravelClassCategories().map((category) => category.tab).toList();
  }

  static String getIconName(String tab) {
    final category = getCategoryByTab(tab);
    return category?.icon ?? "star";
  }

  /// Map pre-flight feedback option to airport leaderboard category
  static String? mapPreFlightOptionToCategory(String option) {
    final optionLower = option.toLowerCase();
    if (optionLower.contains('check-in') || optionLower.contains('checkin')) {
      return 'Check-in Process';
    } else if (optionLower.contains('security') && optionLower.contains('wait')) {
      return 'Security Wait Time';
    } else if (optionLower.contains('boarding')) {
      return 'Boarding Process';
    } else if (optionLower.contains('facilities') || optionLower.contains('shops')) {
      return 'Airport Facilities';
    } else if (optionLower.contains('smooth')) {
      return 'Smooth Experience';
    } else if (optionLower.contains('lounge')) {
      return 'Airline Lounge';
    }
    return null;
  }

  /// Get airport category tabs
  static List<String> getAirportTabs() {
    return getAirportCategories().map((category) => category.tab).toList();
  }

  /// Map airport category to score_type for database queries
  static String mapAirportCategoryToScoreType(String category) {
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('check-in') || categoryLower.contains('checkin')) {
      return 'checkin_process';
    } else if (categoryLower.contains('security')) {
      return 'security_wait';
    } else if (categoryLower.contains('boarding')) {
      return 'boarding_process';
    } else if (categoryLower.contains('facilities')) {
      return 'airport_facilities';
    } else if (categoryLower.contains('smooth')) {
      return 'smooth_experience';
    } else if (categoryLower.contains('lounge')) {
      return 'airline_lounge';
    }
    return categoryLower.replaceAll(' ', '_');
  }
}
