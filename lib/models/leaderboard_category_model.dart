class LeaderboardCategory {
  final String tab;
  final String description;
  final List<String> sourceTags;
  final String formula;
  final String icon;

  const LeaderboardCategory({
    required this.tab,
    required this.description,
    required this.sourceTags,
    required this.formula,
    required this.icon,
  });

  factory LeaderboardCategory.fromJson(Map<String, dynamic> json) {
    return LeaderboardCategory(
      tab: json['tab'],
      description: json['description'],
      sourceTags: List<String>.from(json['source_tags']),
      formula: json['formula'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tab': tab,
      'description': description,
      'source_tags': sourceTags,
      'formula': formula,
      'icon': icon,
    };
  }
}

class LeaderboardCategoryService {
  static const List<LeaderboardCategory> categories = [
    LeaderboardCategory(
      tab: "Wi-Fi Experience",
      description: "Measures satisfaction with inflight internet quality and connectivity.",
      sourceTags: ["Good Wi-Fi", "Poor Wi-Fi", "Wi-Fi connectivity", "Wi-Fi and IFE"],
      formula: "(likes - dislikes) / total_feedback",
      icon: "wifi",
    ),
    LeaderboardCategory(
      tab: "Crew Friendliness",
      description: "Evaluates the helpfulness and service quality of the cabin crew.",
      sourceTags: ["Crew helpful", "Friendly service", "Unfriendly crew", "Cabin crew", "Friendly and helpful service"],
      formula: "(likes - dislikes) / total_feedback",
      icon: "people",
    ),
    LeaderboardCategory(
      tab: "Seat Comfort",
      description: "Assesses passenger comfort and cabin conditions during the flight.",
      sourceTags: ["Comfortable seat", "Uncomfortable seat", "Clean cabin", "Seat comfort", "Cabin cleanliness", "Onboard Comfort"],
      formula: "(likes - dislikes) / total_feedback",
      icon: "chair",
    ),
    LeaderboardCategory(
      tab: "Food & Beverage",
      description: "Tracks satisfaction with meals and drinks onboard.",
      sourceTags: ["Good food", "Cold meal", "Poor quality beverage", "Food and beverage", "Food and Beverage"],
      formula: "(likes - dislikes) / total_feedback",
      icon: "restaurant",
    ),
    LeaderboardCategory(
      tab: "Operations & Timeliness",
      description: "Reflects the smoothness of boarding, baggage handling, and punctuality.",
      sourceTags: ["Smooth boarding", "Delayed boarding", "Gate chaos", "Baggage delay", "Check-in process", "Security line wait time", "Boarding process", "Baggage delivery or ease of connection"],
      formula: "(likes - dislikes) / total_feedback",
      icon: "schedule",
    ),
  ];

  static List<LeaderboardCategory> getAllCategories() {
    return categories;
  }

  static LeaderboardCategory? getCategoryByTab(String tab) {
    try {
      return categories.firstWhere((category) => category.tab == tab);
    } catch (e) {
      return null;
    }
  }

  static List<String> getAllTabs() {
    return categories.map((category) => category.tab).toList();
  }

  static String getIconName(String tab) {
    final category = getCategoryByTab(tab);
    return category?.icon ?? "star";
  }
}

