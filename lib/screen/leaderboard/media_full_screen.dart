import 'package:video_player/video_player.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaFullScreen extends ConsumerStatefulWidget {
  const MediaFullScreen({super.key});

  @override
  ConsumerState<MediaFullScreen> createState() => _MediaFullScreenState();
}

class _MediaFullScreenState extends ConsumerState<MediaFullScreen> {
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, Duration> _videoPositions = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideos();
    });
  }

  void _pauseAllVideos() {
    _videoControllers.forEach((_, controller) {
      controller.pause();
    });
  }

  Future<void> _initVideos() async {
    setState(() {
      isLoading = true;
    });

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final List<dynamic> mediaUrls = args?['imageUrls'] ?? [];

    // Clear existing controllers first
    await Future.forEach(_videoControllers.values, (controller) async {
      await controller.dispose();
    });
    _videoControllers.clear();

    for (var media in mediaUrls) {
      if (media
          .toString()
          .contains(RegExp(r'\.(mp4|mov|avi|wmv)', caseSensitive: false))) {
        try {
          final controller = VideoPlayerController.networkUrl(
            Uri.parse(media),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

          await controller.initialize();
          controller.setLooping(true);

          setState(() {
            _videoControllers[media] = controller;
          });
        } catch (e) {
          debugPrint('Error initializing video $media: $e');
        }
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      // Store position before disposing
      _videoPositions[controller.dataSource] = controller.value.position;
      controller.pause();
      controller.dispose();
      controller.setVolume(0); // Mute before disposing
    }
    _videoControllers.clear();
    _videoPositions.clear(); // Clear stored positions
    super.dispose();
  }

  Widget _buildVideoPlayer(String videoUrl) {
    final controller = _videoControllers[videoUrl];
    if (controller == null) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.grey,
        ),
      );
    }

    if (controller.value.isInitialized) {
      // Restore previous position if available
      if (_videoPositions.containsKey(videoUrl)) {
        controller.seekTo(_videoPositions[videoUrl]!);
        _videoPositions.remove(videoUrl); // Clear after seeking
      }
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller..play()),
      );
    }
    return SizedBox(
      height: 594.0,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    CarouselSliderController buttonCarouselController =
        CarouselSliderController();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final List<dynamic> mediaList = args?['imageUrls'] ?? [];

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (mediaList.isEmpty)
                Container(
                  height: 594.0,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/default.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                CarouselSlider(
                  options: CarouselOptions(
                    viewportFraction: 1,
                    height: MediaQuery.of(context).size.height * 0.7,
                    enableInfiniteScroll: false,
                    onPageChanged: (index, reason) {
                      _pauseAllVideos();
                    },
                  ),
                  items: mediaList.map((media) {
                    return Builder(
                      builder: (BuildContext context) {
                        if (media.toString().contains(RegExp(
                            r'\.(mp4|mov|avi|wmv)',
                            caseSensitive: false))) {
                          return SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: _buildVideoPlayer(media),
                          );
                        } else {
                          return Container(
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(media),
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  }).toList(),
                  carouselController: buttonCarouselController,
                ),
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: AppStyles.circleDecoration,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            (args?['Avatar'] != '' && args?['Avatar'] != null)
                                ? NetworkImage(args?['Avatar'] ?? '')
                                : const AssetImage("assets/images/avatar_1.png")
                                    as ImageProvider,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args?['Name'] ?? '',
                          style: AppStyles.textStyle_14_600,
                        ),
                        Text(
                          args?['Date'] ?? '',
                          style: AppStyles.textStyle_14_400
                              .copyWith(color: const Color(0xFF02020A)),
                        )
                      ],
                    )
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                const VerifiedButton(),
                const SizedBox(
                  height: 14,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        "Was in ",
                        style: AppStyles.textStyle_14_400
                            .copyWith(color: const Color(0xFF38433E)),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        "${args?['Usedairport'] ?? ''}, ",
                        style: AppStyles.textStyle_14_600,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Premium Economy',
                        style: AppStyles.textStyle_14_600,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  args?['Content'] ?? '',
                  style: AppStyles.textStyle_14_400,
                ),
                const SizedBox(
                  height: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VerifiedButton extends StatelessWidget {
  const VerifiedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 24,
      decoration: BoxDecoration(
          color: const Color(0xff181818),
          borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text("Verified",
            style: AppStyles.textStyle_14_400.copyWith(color: Colors.white)),
      ),
    );
  }
}
