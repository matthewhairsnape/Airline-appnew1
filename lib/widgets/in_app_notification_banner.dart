import 'package:flutter/material.dart';

/// In-app notification banner that appears at the top of the screen
class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration displayDuration;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const InAppNotificationBanner({
    Key? key,
    required this.title,
    required this.body,
    this.onTap,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 5),
    this.backgroundColor,
    this.textColor,
    this.icon,
  }) : super(key: key);

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();

  /// Show notification banner as an overlay
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration displayDuration = const Duration(seconds: 5),
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
  }) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎨 IN-APP NOTIFICATION BANNER - SHOW CALLED');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Title: $title');
    print('Body: $body');
    print('Context is valid: ${context.mounted}');
    
    try {
      // Remove existing overlay if any
      if (_currentOverlay != null) {
        print('🗑️ Removing existing overlay');
        _currentOverlay?.remove();
        _currentOverlay = null;
      }

      print('🔍 Getting overlay from context...');
      
      // Use findAncestorStateOfType to get the overlay more reliably
      OverlayState? overlay;
      try {
        // Try to get the overlay state directly from the element tree
        overlay = context.findAncestorStateOfType<OverlayState>();
        
        if (overlay != null) {
          print('✅ Overlay obtained from ancestor');
        } else {
          print('⚠️ No overlay found in ancestor tree');
          print('⚠️ In-app banner cannot be shown without overlay');
          return;
        }
      } catch (e) {
        print('⚠️ Could not get overlay: $e');
        print('⚠️ In-app banner cannot be shown without overlay');
        return;
      }
      
      late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 8,
        right: 8,
        child: Material(
          color: Colors.transparent,
          child: InAppNotificationBanner(
            title: title,
            body: body,
            onTap: () {
              overlayEntry.remove();
              _currentOverlay = null;
              onTap?.call();
            },
            onDismiss: () {
              overlayEntry.remove();
              _currentOverlay = null;
            },
            displayDuration: displayDuration,
            backgroundColor: backgroundColor,
            textColor: textColor,
            icon: icon,
          ),
        ),
      ),
    );

    _currentOverlay = overlayEntry;
      print('📥 Inserting overlay entry...');
      overlay.insert(overlayEntry);
      print('✅ In-app banner overlay inserted!');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Auto-dismiss after duration
      Future.delayed(displayDuration, () {
        if (_currentOverlay == overlayEntry) {
          print('⏰ Auto-dismissing in-app banner');
          overlayEntry.remove();
          _currentOverlay = null;
        }
      });
    } catch (e, stackTrace) {
      print('❌ ERROR SHOWING IN-APP BANNER: $e');
      print('Stack trace: $stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-dismiss animation
    Future.delayed(widget.displayDuration - const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () {
            _controller.reverse().then((_) {
              widget.onTap?.call();
            });
          },
          onVerticalDragUpdate: (details) {
            // Swipe up to dismiss
            if (details.delta.dy < -5) {
              _controller.reverse().then((_) {
                widget.onDismiss?.call();
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? const Color(0xFF323232),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _controller.reverse().then((_) {
                    widget.onTap?.call();
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.textColor?.withOpacity(0.2) ??
                              Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.icon ?? Icons.notifications_active,
                          color: widget.textColor ?? Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: widget.textColor ?? Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.body,
                              style: TextStyle(
                                color: (widget.textColor ?? Colors.white)
                                    .withOpacity(0.9),
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Dismiss button
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: (widget.textColor ?? Colors.white)
                              .withOpacity(0.7),
                          size: 20,
                        ),
                        onPressed: () {
                          _controller.reverse().then((_) {
                            widget.onDismiss?.call();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

