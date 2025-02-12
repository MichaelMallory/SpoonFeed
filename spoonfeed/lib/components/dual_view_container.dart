import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'video_player_fullscreen.dart';
import '../models/video_model.dart';
import '../services/game_service.dart';

class DualViewContainer extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final VoidCallback? onRetry;

  const DualViewContainer({
    Key? key,
    required this.video,
    required this.isActive,
    this.onRetry,
  }) : super(key: key);

  @override
  DualViewContainerState createState() => DualViewContainerState();
}

class DualViewContainerState extends State<DualViewContainer> {
  @override
  Widget build(BuildContext context) {
    return VideoPlayerFullscreen(
      key: ValueKey('fullscreen-${widget.video.id}'),
      video: widget.video,
      isActive: widget.isActive,
      shouldPreload: false,
      isGameMode: true,
      onRetry: () {
        if (widget.onRetry != null) {
          widget.onRetry!();
        }
      },
    );
  }
} 