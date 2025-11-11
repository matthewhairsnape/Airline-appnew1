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
