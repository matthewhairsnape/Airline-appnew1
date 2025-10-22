import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/screen/leaderboard/widgets/basic_black_button.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/provider/user_data_provider.dart';

class FeedbackCard extends ConsumerStatefulWidget {
  const FeedbackCard(
      {super.key, required this.singleFeedback, required this.thumbnailHeight});

  final Map<String, dynamic> singleFeedback;
  final double thumbnailHeight;

  @override
  ConsumerState<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<FeedbackCard> {
  final CarouselSliderController buttonCarouselController =
      CarouselSliderController();

  bool isFavorite = false;
  int? selectedEmojiIndex;
  late int totalFavorites;

  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, Duration> _videoPositions = {};

  @override
  void deactivate() {
    // Pause and clear cache when widget is not visible
    for (var controller in _videoControllers.values) {
      try {
        if (controller.value.isInitialized) {
          controller.pause();
          controller.setVolume(0);
        }
      } catch (e) {
        debugPrint('Error in deactivate for video controller: $e');
      }
    }
    super.deactivate();
  }

  @override
  void didUpdateWidget(FeedbackCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-initialize video players when feedback data changes
    if (oldWidget.singleFeedback != widget.singleFeedback) {
      // Only proceed if widget is still mounted
      if (!mounted) return;
      
      // Clean up old video controllers safely
      _disposeVideoControllers();
      
      // Initialize new video controllers only if still mounted
      if (mounted) {
        initializeVideoPlayer();
      }
    }
  }

  @override
  void dispose() {
    _disposeVideoControllers();
    super.dispose();
  }

  /// Safely dispose of all video controllers
  void _disposeVideoControllers() {
    for (var controller in _videoControllers.values) {
      try {
        // Store position before disposing
        _videoPositions[controller.dataSource] = controller.value.position;
        controller.pause();
        // Clear video buffer before disposing
        controller.setVolume(0);
        controller.removeListener(() {});
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing video controller: $e');
      }
    }
    _videoControllers.clear();
    _videoPositions.clear(); // Clear stored positions
  }

  @override
  void initState() {
    super.initState();
    initializeVideoPlayer();
  }

  void initializeVideoPlayer() {
    if (!mounted || widget.singleFeedback['imageUrls'] == null) return;

    for (var media in widget.singleFeedback['imageUrls']) {
      if (media != null &&
          media
              .toString()
              .toLowerCase()
              .contains(RegExp(r'\.(mp4|mov|avi|wmv)', caseSensitive: false))) {
        try {
          // Check if controller already exists to avoid duplicates
          if (_videoControllers.containsKey(media)) {
            continue;
          }
          
          _videoControllers[media] = VideoPlayerController.networkUrl(
            Uri.parse(media), // Convert String to Uri
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )..initialize().then((_) {
              if (mounted && _videoControllers.containsKey(media)) {
                setState(() {
                  _videoControllers[media]?.setVolume(0.0);
                  _videoControllers[media]?.setLooping(true);
                  _handleVideoState();
                });
              }
            }).catchError((error) {
              debugPrint('Error initializing video controller for $media: $error');
              // Remove failed controller
              _videoControllers.remove(media);
            });
        } catch (e) {
          debugPrint('Error creating video controller: $e');
        }
      }
    }

    final userId = ref.read(userDataProvider)?['userData']?['_id'];
    final ratingList = widget.singleFeedback['rating'] as List?;
    isFavorite = ratingList?.contains(userId) ?? false;
    totalFavorites = ratingList?.length ?? 0;
  }

  void sharedFunction(String url) {
    Share.share(url);
  }

  void _handleVideoState() {
    if (!mounted) return;
    
    _videoControllers.forEach((url, controller) {
      try {
        if (controller.value.isInitialized && !controller.value.isPlaying) {
          controller.play();
        }
      } catch (e) {
        debugPrint('Error handling video state for $url: $e');
      }
    });
  }

  Widget _buildVideoPlayer(String videoUrl) {
    final controller = _videoControllers[videoUrl];
    if (controller == null) return Container();

    if (controller.value.isInitialized) {
      // Set volume to 0 for mute
      controller.setVolume(0);

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
    return Center(
      child: CircularProgressIndicator(
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.singleFeedback['reviewer'] == null ||
        widget.singleFeedback['airline'] == null) {
      return Container();
    }
    final userId = ref.watch(userDataProvider)?['userData']?['_id'];
    final List<dynamic> imageUrls = widget.singleFeedback['imageUrls'] ?? [];

    return SizedBox(
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
                  backgroundImage: (widget.singleFeedback['reviewer']
                                  ['profilePhoto'] !=
                              '' &&
                          widget.singleFeedback['reviewer']['profilePhoto'] !=
                              null)
                      ? NetworkImage(
                          '${widget.singleFeedback['reviewer']['profilePhoto']}')
                      : const AssetImage("assets/images/avatar_1.png")
                          as ImageProvider,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.singleFeedback['reviewer']['name'] ?? '',
                      style: AppStyles.textStyle_14_600,
                    ),
                    Row(
                      children: [
                        Text(
                          'Rated ',
                          style: AppStyles.textStyle_14_400
                              .copyWith(color: Colors.grey),
                        ),
                        Text(
                          '${(widget.singleFeedback['score'] ?? 0).toStringAsFixed(1)}/10',
                          style: AppStyles.textStyle_14_600
                              .copyWith(color: Colors.black),
                        ),
                        Text(
                          ' on ${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(8, 10)}.${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(5, 7)}.${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(2, 4)}',
                          style: AppStyles.textStyle_14_400
                              .copyWith(color: Colors.grey),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: 12),
          BasicBlackButton(
              mywidth: 68,
              myheight: 24,
              myColor: Colors.black,
              btntext: "Verified"),
          SizedBox(
            height: 12,
          ),
          widget.singleFeedback['from'] != null
              ? Row(
                  children: [
                    Text('Flex with',
                        style: AppStyles.textStyle_14_400
                            .copyWith(color: Color(0xFF38433E))),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${widget.singleFeedback['airline']['name'].toString().length > 13 ? '${widget.singleFeedback['airline']['name'].toString().substring(0, 13)}..' : widget.singleFeedback['airline']['name']}, ${widget.singleFeedback['classTravel']}',
                          style: AppStyles.textStyle_14_600),
                    )
                  ],
                )
              : Row(
                  children: [
                    Text('Flex in',
                        style: AppStyles.textStyle_14_400
                            .copyWith(color: Color(0xFF38433E))),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('${widget.singleFeedback['airport']['city']}',
                          style: AppStyles.textStyle_14_600),
                    ),
                  ],
                ),
          SizedBox(height: 7),
          if (widget.singleFeedback['from'] != null)
            Row(
              children: [
                Text('Flex from',
                    style: AppStyles.textStyle_14_400
                        .copyWith(color: Color(0xFF38433E))),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${widget.singleFeedback['from']['city'].toString().length > 12 ? '${widget.singleFeedback['from']['city'].toString().substring(0, 12)}..' : widget.singleFeedback['from']['city']} -> ${widget.singleFeedback['to']['city'].toString().length > 12 ? '${widget.singleFeedback['to']['city'].toString().substring(0, 12)}..' : widget.singleFeedback['to']['city']}',
                      style: AppStyles.textStyle_14_600),
                ),
              ],
            ),
          SizedBox(height: 11),
          if (imageUrls.isNotEmpty)
            Stack(
              children: [
                widget.singleFeedback['from'] != null
                    ? InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                              context, AppRoutes.mediafullscreen,
                              arguments: {
                                'userId': userId,
                                'feedbackId': widget.singleFeedback['_id'],
                                'imageUrls': imageUrls,
                                'Name': widget.singleFeedback['reviewer']
                                    ['name'],
                                'Avatar': widget.singleFeedback['reviewer']
                                    ['profilePhoto'],
                                'Date':
                                    'Rated ${(widget.singleFeedback['score'] ?? 0).toStringAsFixed(1)}/10 on ${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(8, 10)}.${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(5, 7)}.${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(2, 4)}',
                                'Usedairport': widget.singleFeedback['airline']
                                    ['name'],
                                'Content': widget.singleFeedback['comment'] !=
                                            null &&
                                        widget.singleFeedback['comment'] != ''
                                    ? widget.singleFeedback['comment']
                                    : '',
                                'rating': totalFavorites.toString(),
                              });
                        },
                        child: CarouselSlider(
                          options: CarouselOptions(
                            viewportFraction: 1,
                            height: 189,
                            enableInfiniteScroll: false,
                          ),
                          carouselController: buttonCarouselController,
                          items: imageUrls.map((mediaItem) {
                            return Builder(builder: (BuildContext context) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: SizedBox(
                                  height: 189,
                                  child: mediaItem
                                          .toString()
                                          .toLowerCase()
                                          .contains(
                                              RegExp(r'\.(mp4|mov|avi|wmv)$'))
                                      ? _buildVideoPlayer(mediaItem)
                                      : Container(
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: NetworkImage('$mediaItem'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            });
                          }).toList(),
                        ),
                      )
                    : InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                              context, AppRoutes.mediafullscreen,
                              arguments: {
                                'userId': userId,
                                'feedbackId': widget.singleFeedback['_id'],
                                'imageUrls': imageUrls,
                                'Name': widget.singleFeedback['reviewer']
                                    ['name'],
                                'Avatar': widget.singleFeedback['reviewer']
                                    ['profilePhoto'],
                                'Date':
                                    'Rated ${(widget.singleFeedback['score'] ?? 0).toStringAsFixed(1)}/10 on ${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(8, 10)}.${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(5, 7)}.${DateTime.parse(widget.singleFeedback['date'] ?? DateTime.now().toString()).toLocal().toString().substring(2, 4)}',
                                'Usedairport': widget.singleFeedback['airport']
                                    ['name'],
                                'Content': widget.singleFeedback['comment'] !=
                                            null &&
                                        widget.singleFeedback['comment'] != ''
                                    ? widget.singleFeedback['comment']
                                    : '',
                                'rating': totalFavorites.toString(),
                              });
                        },
                        child: CarouselSlider(
                          options: CarouselOptions(
                            viewportFraction: 1,
                            height: 189,
                            enableInfiniteScroll: false,
                          ),
                          carouselController: buttonCarouselController,
                          items: imageUrls.map((mediaItem) {
                            return Builder(builder: (BuildContext context) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: SizedBox(
                                  height: 189,
                                  child: mediaItem
                                          .toString()
                                          .toLowerCase()
                                          .contains(
                                              RegExp(r'\.(mp4|mov|avi|wmv)$'))
                                      ? _buildVideoPlayer(mediaItem)
                                      : Container(
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: NetworkImage('$mediaItem'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            });
                          }).toList(),
                        ),
                      ),
              ],
            ),
          const SizedBox(height: 11),
          SizedBox(
            height: 40,
            child: Text(
              widget.singleFeedback['comment'] != null &&
                      widget.singleFeedback['comment'].isNotEmpty
                  ? widget.singleFeedback['comment']
                  : 'No comment given',
              style: widget.singleFeedback['comment'] != null &&
                      widget.singleFeedback['comment'].isNotEmpty
                  ? AppStyles.textStyle_14_400
                  : AppStyles.textStyle_14_400
                      .copyWith(fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  onPressed: () async {
                    Share.share(
                        "Hey! 👋 Check out this amazing app that helps you discover and share travel experiences!\nJoin me on Airshiare and let's explore together! 🌟✈️\n\nDownload now: https://beta.itunes.apple.com/v1/app/6739448029",
                        subject:
                            'Join me on Airshiare - Your Travel Companion!');
                  },
                  icon: SvgPicture.asset(
                    'assets/icons/share.svg',
                  )

                  // Image.asset('assets/icons/share.svg'),
                  ),
              widget.singleFeedback['from'] != null
                  ? Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            setState(() {
                              isFavorite = !isFavorite;

                              if (isFavorite) {
                                totalFavorites++;
                              } else {
                                totalFavorites--;
                              }
                            });

                            try {
                              // Update reaction in backend

                              final response = await http.post(
                                Uri.parse(
                                    '$apiUrl/api/v1/airline-review/update'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                },
                                body: jsonEncode({
                                  'feedbackId': widget.singleFeedback['_id'],
                                  'user_id': userId,
                                  'isFavorite': isFavorite,
                                }),
                              );

                              if (response.statusCode == 200) {
                              } else {
                                debugPrint('Failed to update reaction');
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              CustomSnackBar.error(
                                  context, "Something went wrong");
                            }
                          },
                          icon: isFavorite
                              ? Icon(Icons.favorite, color: Colors.red)
                              : Icon(Icons.favorite_border),
                        ),
                        SizedBox(width: 8),
                        AnimatedFlipCounter(
                          value: totalFavorites,
                          textStyle: AppStyles.textStyle_16_600,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            setState(() {
                              isFavorite = !isFavorite;
                              if (isFavorite) {
                                totalFavorites++;
                              } else {
                                totalFavorites--;
                              }
                            });

                            try {
                              // Update reaction in backend

                              final response = await http.post(
                                Uri.parse(
                                    '$apiUrl/api/v1/airport-review/update'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                },
                                body: jsonEncode({
                                  'feedbackId': widget.singleFeedback['_id'],
                                  'user_id': userId,
                                  'isFavorite': isFavorite,
                                }),
                              );

                              if (response.statusCode == 200) {
                              } else {
                                if (!context.mounted) return;
                                CustomSnackBar.error(
                                    context, "Something went wrong");
                                debugPrint('Failed to update reaction');
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              CustomSnackBar.error(
                                  context, "Something went wrong");
                            }
                          },
                          icon: isFavorite
                              ? Icon(Icons.favorite, color: Colors.red)
                              : Icon(Icons.favorite_border),
                        ),
                        SizedBox(width: 8),
                        AnimatedFlipCounter(
                          value: totalFavorites,
                          textStyle: AppStyles.textStyle_16_600,
                        ),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
