import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class SkipScreen extends StatefulWidget {
  const SkipScreen({super.key});

  @override
  State<SkipScreen> createState() => _SkipScreenState();
}

class _SkipScreenState extends State<SkipScreen> {
  int selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<String> titleList = [
    "Unbiased Reviews",
    "Shared Flight Feedback",
    "Real-Time Insights"
  ];

  final List<String> contentList = [
    "Explore real, verified reviews to help you make informed travel choices",
    "Your voice matters! Share your experiences and help improve air travel for everyone",
    "Stay updated and share feedback while you're still in the moment"
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => selectedIndex = index),
            itemCount: 3,
            itemBuilder: (context, index) => _buildPage(index, screenSize),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(screenSize),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, Size screenSize) {
    return Stack(
      children: [
        Container(
          width: screenSize.width,
          height: screenSize.height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/skipscreen$index.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withAlpha(127),
                BlendMode.darken,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(127),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 35,
          top: screenSize.height * 0.15,
          child: SizedBox(
            width: screenSize.width - 70,
            child: _buildHeaderText(index),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(Size screenSize) {
    return Container(
      height: screenSize.height * 0.4,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xff97A09C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  titleList[selectedIndex],
                  style: AppStyles.textStyle_24_600.copyWith(
                    letterSpacing: 1.0,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  contentList[selectedIndex],
                  style: AppStyles.textStyle_15_400.copyWith(
                    height: 1.6,
                    fontSize: 17,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                _buildPageIndicator(),
              ],
            ),
          ),
          const Spacer(),
          _buildNavigationButton(),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: 6,
          width: selectedIndex == index ? 32 : 6,
          decoration: BoxDecoration(
            color: selectedIndex == index
                ? AppStyles.mainColor
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
            boxShadow: selectedIndex == index
                ? [
                    BoxShadow(
                      color: AppStyles.mainColor.withAlpha(104),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: MainButton(
        text: selectedIndex == 2 ? "Get Started" : "Next",
        onPressed: () {
          if (selectedIndex < 2) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          } else {
            Navigator.pushNamed(context, AppRoutes.startreviews);
          }
        },
      ),
    );
  }

  Widget _buildHeaderText(int index) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      height: 1.1,
      shadows: [
        Shadow(
          offset: Offset(2, 2),
          blurRadius: 8,
          color: Colors.black45,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experience',
          style: baseStyle.copyWith(
            fontSize: 54,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          'Feedback',
          style: baseStyle.copyWith(
            fontSize: 54,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'that takes',
          style: baseStyle.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          'Flight',
          style: baseStyle.copyWith(
            fontSize: 64,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                offset: Offset(3, 3),
                blurRadius: 10,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
