class LeaderboardCategory {
  final String tab;
  final String description;
  final List<String> sourceTags;
  final String formula;
  final String icon;
  final bool isTravelClass;

  const LeaderboardCategory({
    required this.tab,
    required this.description,
    required this.sourceTags,
    required this.formula,
    required this.icon,
    this.isTravelClass = false,
  });

  factory LeaderboardCategory.fromJson(Map<String, dynamic> json) {
    return LeaderboardCategory(
      tab: json['tab'],
      description: json['description'],
      sourceTags: List<String>.from(json['source_tags']),
      formula: json['formula'],
      icon: json['icon'],
      isTravelClass: json['is_travel_class'] ?? false,
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
    };
  }
}

class LeaderboardCategoryService {
  static const List<LeaderboardCategory> categories = [
    LeaderboardCategory(
      tab: "Business Class",
      description:
          "Business cabin rankings sourced directly from verified passenger scoring (top 10, verbatim).",
      sourceTags: [
        "Business Class",
        "Business cabin",
        "Premium cabin",
      ],
      formula: "Verbatim seed scores from supplied business-class data.",
      icon: "business",
      isTravelClass: true,
    ),
    LeaderboardCategory(
      tab: "Economy Class",
      description:
          "Economy cabin rankings sourced directly from verified passenger scoring (top 10, verbatim).",
      sourceTags: [
        "Economy Class",
        "Main cabin",
        "Coach",
      ],
      formula: "Verbatim seed scores from supplied economy-class data.",
      icon: "economy",
      isTravelClass: true,
    ),
    LeaderboardCategory(
      tab: "Wi-Fi Experience",
      description:
          "Measures satisfaction with inflight internet quality and connectivity.",
      sourceTags: [
        "Good Wi-Fi",
        "Poor Wi-Fi",
        "Wi-Fi connectivity",
        "Wi-Fi and IFE"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "wifi",
    ),
    LeaderboardCategory(
      tab: "Crew Friendliness",
      description:
          "Evaluates the helpfulness and service quality of the cabin crew.",
      sourceTags: [
        "Crew helpful",
        "Friendly service",
        "Unfriendly crew",
        "Cabin crew",
        "Friendly and helpful service"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "people",
    ),
    LeaderboardCategory(
      tab: "Seat Comfort",
      description:
          "Assesses passenger comfort and cabin conditions during the flight.",
      sourceTags: [
        "Comfortable seat",
        "Uncomfortable seat",
        "Clean cabin",
        "Seat comfort",
        "Cabin cleanliness",
        "Onboard Comfort"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "chair",
    ),
    LeaderboardCategory(
      tab: "Food & Beverage",
      description: "Tracks satisfaction with meals and drinks onboard.",
      sourceTags: [
        "Good food",
        "Cold meal",
        "Poor quality beverage",
        "Food and beverage",
        "Food and Beverage"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "restaurant",
    ),
    LeaderboardCategory(
      tab: "Operations & Timeliness",
      description:
          "Reflects the smoothness of boarding, baggage handling, and punctuality.",
      sourceTags: [
        "Smooth boarding",
        "Delayed boarding",
        "Gate chaos",
        "Baggage delay",
        "Check-in process",
        "Security line wait time",
        "Boarding process",
        "Baggage delivery or ease of connection"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "schedule",
    ),
    LeaderboardCategory(
      tab: "Inflight Entertainment",
      description:
          "Captures satisfaction with onboard movies, TV, and streaming options.",
      sourceTags: [
        "Inflight entertainment",
        "IFE",
        "Movies",
        "Onboard entertainment",
        "Seatback screen"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "movie",
    ),
    LeaderboardCategory(
      tab: "Aircraft Condition",
      description:
          "Tracks passenger perception of aircraft cleanliness, maintenance, and cabin condition.",
      sourceTags: [
        "Aircraft condition",
        "Cabin condition",
        "Cabin maintenance",
        "Cabin cleanliness",
        "Aircraft cleanliness"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "aircraft",
    ),
    LeaderboardCategory(
      tab: "Arrival Experience",
      description:
          "Measures satisfaction with the post-flight experience, including arrival processes.",
      sourceTags: [
        "Arrival experience",
        "Arrival process",
        "Customs",
        "Immigration",
        "Post-flight"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "arrival",
    ),
    LeaderboardCategory(
      tab: "Booking Experience",
      description:
          "Evaluates how passengers feel about the digital and offline booking journey.",
      sourceTags: [
        "Booking experience",
        "Reservation system",
        "Ticket booking",
        "Website UX",
        "App booking"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "laptop",
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
        "Hygiene"
      ],
      formula: "(likes - dislikes) / total_feedback",
      icon: "cleaning",
    ),
  ];

  static List<LeaderboardCategory> getAllCategories() {
    return categories;
  }

  static List<LeaderboardCategory> getTravelClassCategories() {
    return categories.where((category) => category.isTravelClass).toList();
  }

  static List<LeaderboardCategory> getPrimaryCategories() {
    return categories.where((category) => !category.isTravelClass).toList();
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
}
