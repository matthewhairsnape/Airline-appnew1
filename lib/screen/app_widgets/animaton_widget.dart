import 'package:flutter/material.dart';
import 'package:flutter_emoji_feedback/flutter_emoji_feedback.dart';
import 'package:flutter_emoji_feedback/gen/assets.gen.dart';

class AnimationS extends StatefulWidget {
  const AnimationS({super.key});

  @override
  State<AnimationS> createState() => _AnimationSState();
}

class _AnimationSState extends State<AnimationS> {
  int? rating;
  List<EmojiModel> drawnEmojiPreset = [
    EmojiModel(
      src: "assets/emoji_1.svg",
      label: 'Terrible',
      package: 'flutter_emoji_feedback',
    ),
    EmojiModel(
      src: Assets.hdBad,
      label: 'Bad',
      package: 'flutter_emoji_feedback',
    ),
    EmojiModel(
      src: Assets.hdGood,
      label: 'Good',
      package: 'flutter_emoji_feedback',
    ),
    EmojiModel(
      src: Assets.hdVeryGood,
      label: 'Very good',
      package: 'flutter_emoji_feedback',
    ),
    EmojiModel(
      src: Assets.hdAwesome,
      label: 'Awesome',
      package: 'flutter_emoji_feedback',
    ),
  ];
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: SizedBox(
          height: 200,
          child: EmojiFeedback(
            rating: rating,
            emojiPreset: drawnEmojiPreset,
            animDuration: const Duration(milliseconds: 300),
            curve: Curves.bounceIn,
            inactiveElementScale: .5,
            enableFeedback: true,
            spaceBetweenItems: 3,
            onChanged: (value) {
              setState(() {
                rating = value;
              });
            },
          ),
        ),
      ),
    );
  }
}
