import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import 'pinned_comment_widget.dart';

const kTransitionDuration = Duration(milliseconds: 500);
const kEnterScale = 0.8;
const kExitScale = 0.8;
const kEnterOffset = Offset(0, -0.3);
const kExitOffset = Offset(0, 1.0);

class AnimatedPinnedComment extends StatefulWidget {
  final CommentModel comment;
  final Function(CommentModel)? onDelete;
  final VoidCallback? onUnpin;
  final bool isEntering;
  final bool isExiting;

  const AnimatedPinnedComment({
    Key? key,
    required this.comment,
    this.onDelete,
    this.onUnpin,
    this.isEntering = false,
    this.isExiting = false,
  }) : super(key: key);

  @override
  State<AnimatedPinnedComment> createState() => _AnimatedPinnedCommentState();
}

class _AnimatedPinnedCommentState extends State<AnimatedPinnedComment> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print('🎭 [AnimatedPinnedComment] Initializing animations for comment ${widget.comment.id}');
    try {
      _controller = AnimationController(
        duration: kTransitionDuration,
        vsync: this,
      );

      _setupAnimations();

      if (widget.isEntering) {
        print('⬆️ [AnimatedPinnedComment] Starting enter animation');
        _controller.forward();
      } else if (widget.isExiting) {
        print('⬇️ [AnimatedPinnedComment] Starting exit animation');
        _controller.reverse();
      } else {
        print('✨ [AnimatedPinnedComment] Setting initial animation state');
        _controller.value = 1.0;
      }
    } catch (e) {
      print('❌ [AnimatedPinnedComment] Error initializing animations: $e');
      rethrow;
    }
  }

  void _setupAnimations() {
    try {
      _scaleAnimation = Tween<double>(
        begin: widget.isEntering ? kEnterScale : 1.0,
        end: widget.isExiting ? kExitScale : 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      _opacityAnimation = Tween<double>(
        begin: widget.isEntering ? 0.0 : 1.0,
        end: widget.isExiting ? 0.0 : 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      _slideAnimation = Tween<Offset>(
        begin: widget.isEntering ? kEnterOffset : Offset.zero,
        end: widget.isExiting ? kExitOffset : Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      _sizeAnimation = Tween<double>(
        begin: widget.isEntering ? 0.0 : 1.0,
        end: widget.isExiting ? 0.0 : 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      _fadeAnimation = Tween<double>(
        begin: widget.isEntering ? 0.0 : 1.0,
        end: widget.isExiting ? 0.0 : 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      // Add status listener for logging
      _controller.addStatusListener((status) {
        switch (status) {
          case AnimationStatus.completed:
            print('✅ [AnimatedPinnedComment] Animation completed for ${widget.comment.id}');
            break;
          case AnimationStatus.dismissed:
            print('🔄 [AnimatedPinnedComment] Animation dismissed for ${widget.comment.id}');
            break;
          case AnimationStatus.forward:
            print('▶️ [AnimatedPinnedComment] Animation starting forward for ${widget.comment.id}');
            break;
          case AnimationStatus.reverse:
            print('◀️ [AnimatedPinnedComment] Animation starting reverse for ${widget.comment.id}');
            break;
        }
      });
    } catch (e) {
      print('❌ [AnimatedPinnedComment] Error setting up animations: $e');
      rethrow;
    }
  }

  @override
  void didUpdateWidget(AnimatedPinnedComment oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    try {
      if (widget.isExiting && !oldWidget.isExiting) {
        print('🔄 [AnimatedPinnedComment] Transitioning to exit state for ${widget.comment.id}');
        if (_controller.isAnimating) {
          print('⚠️ [AnimatedPinnedComment] Stopping current animation before reverse');
          _controller.stop();
        }
        _controller.reverse();
      } else if (widget.isEntering && !oldWidget.isEntering) {
        print('🔄 [AnimatedPinnedComment] Transitioning to enter state for ${widget.comment.id}');
        if (_controller.isAnimating) {
          print('⚠️ [AnimatedPinnedComment] Stopping current animation before forward');
          _controller.stop();
        }
        _controller.forward();
      }
    } catch (e) {
      print('❌ [AnimatedPinnedComment] Error updating animation state: $e');
      // Don't rethrow here as it might break the UI
    }
  }

  @override
  void dispose() {
    print('🗑️ [AnimatedPinnedComment] Disposing animations for ${widget.comment.id}');
    try {
      _controller.dispose();
    } catch (e) {
      print('⚠️ [AnimatedPinnedComment] Error disposing animations: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: PinnedCommentWidget(
          comment: widget.comment,
          onDelete: widget.onDelete != null ? () => widget.onDelete!(widget.comment) : null,
          onUnpin: widget.onUnpin,
        ),
      ),
    );
  }
} 