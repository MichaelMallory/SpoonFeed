import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/comment_model.dart';
import '../services/video/video_service.dart';
import '../services/game_service.dart';
import 'pinned_comment_widget.dart';
import 'animated_pinned_comment.dart';

// Use same duration as AnimatedPinnedComment
const kTransitionCleanupDelay = kTransitionDuration;

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCommentCount;
  final VideoService videoService;
  final Function(int) onCommentCountUpdated;
  final Function(CommentModel)? onCommentDeleted;
  final Function(CommentModel)? onCommentPinned;
  final Function(CommentModel)? onCommentUnpinned;

  const CommentsSheet({
    Key? key,
    required this.videoId,
    required this.initialCommentCount,
    required this.videoService,
    required this.onCommentCountUpdated,
    this.onCommentDeleted,
    this.onCommentPinned,
    this.onCommentUnpinned,
  }) : super(key: key);

  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;
  int _lastCommentCount = 0;
  late final GameService gameService;
  CommentModel? _pinnedComment;
  bool _isLoadingPinned = true;
  bool _isTransitioning = false;
  CommentModel? _previousPinnedComment;
  StreamSubscription<CommentModel?>? _pinnedCommentSubscription;

  @override
  void initState() {
    super.initState();
    print('🔵 Initializing CommentsSheet');
    gameService = Provider.of<GameService>(context, listen: false);
    _loadPinnedComment();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _pinnedCommentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPinnedComment() async {
    setState(() {
      _isLoadingPinned = true;
    });

    try {
      debugPrint('🔍 Loading pinned comment for video ${widget.videoId}');
      final pinnedComment = await gameService.getPinnedComment(widget.videoId);
      
      if (mounted) {
        setState(() {
          if (_pinnedComment != null && pinnedComment != _pinnedComment) {
            debugPrint('🔄 Pinned comment changed, starting transition');
            _previousPinnedComment = _pinnedComment;
            _isTransitioning = true;
            
            Future.delayed(kTransitionCleanupDelay, () {
              if (mounted) {
                setState(() {
                  debugPrint('🧹 Cleaning up previous pinned comment');
                  _previousPinnedComment = null;
                  _isTransitioning = false;
                });
              }
            });
          }
          
          _pinnedComment = pinnedComment;
          _isLoadingPinned = false;
        });
      }
      
      // Set up stream subscription for real-time updates
      _pinnedCommentSubscription?.cancel();
      _pinnedCommentSubscription = gameService.streamPinnedComment(widget.videoId).listen(
        (comment) {
          debugPrint('📬 Received pinned comment update: ${comment?.id}');
          if (mounted) {
            setState(() {
              if (_pinnedComment != null && comment != _pinnedComment) {
                _previousPinnedComment = _pinnedComment;
                _isTransitioning = true;
                
                Future.delayed(kTransitionCleanupDelay, () {
                  if (mounted) {
                    setState(() {
                      _previousPinnedComment = null;
                      _isTransitioning = false;
                    });
                  }
                });
              }
              _pinnedComment = comment;
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Error in pinned comment stream: $error');
        },
      );
      
      debugPrint('✅ Pinned comment loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading pinned comment: $e');
      if (mounted) {
        setState(() {
          _isLoadingPinned = false;
        });
      }
    }
  }

  void _updateCommentCount(int newCount) {
    if (_lastCommentCount != newCount) {
      _lastCommentCount = newCount;
      Future.microtask(() {
        if (mounted) {
          widget.onCommentCountUpdated(newCount);
        }
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!mounted) return;
    
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.videoService.addComment(
        widget.videoId,
        text,
      );

      _commentController.clear();
      
    } catch (e) {
      print('[CommentsSheet] Error submitting comment: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post comment. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    try {
      await gameService.deleteComment(widget.videoId, comment);
      if (widget.onCommentDeleted != null) {
        widget.onCommentDeleted!(comment);
      }
    } catch (e) {
      print('🔴 Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: $e')),
        );
      }
    }
  }

  Future<void> _unpinComment(CommentModel comment) async {
    try {
      print('🔵 Unpinning comment ${comment.id}');
      final success = await gameService.unpinComment(widget.videoId, comment);
      if (success) {
        print('✅ Successfully unpinned comment ${comment.id}');
        if (widget.onCommentUnpinned != null) {
          widget.onCommentUnpinned!(comment);
        }
      } else {
        print('❌ Failed to unpin comment ${comment.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unpin comment')),
          );
        }
      }
    } catch (e) {
      print('🔴 Error unpinning comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unpinning comment: $e')),
        );
      }
    }
  }

  Future<void> _handleDeleteComment(CommentModel comment) async {
    try {
      await _deleteComment(comment);
    } catch (e) {
      print('🔴 Error in _handleDeleteComment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header with real-time comment count
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: widget.videoService.streamVideoMetadata(widget.videoId),
            builder: (context, snapshot) {
              final commentCount = snapshot.data?.get('comments') as int? ?? 0;
              _updateCommentCount(commentCount);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comments ($commentCount)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
          ),

          // Comments List with real-time updates
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.videoService.streamVideoComments(widget.videoId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!
                    .map((doc) => CommentModel.fromMap(doc))
                    .where((comment) => 
                        comment.text.isNotEmpty && 
                        comment.userId.isNotEmpty &&
                        !comment.isPinned) // Exclude pinned comment from main list
                    .toList();

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Pinned Comment Section
                    SliverToBoxAdapter(
                      child: _isLoadingPinned
                          ? const SizedBox.shrink() // Remove loading spinner
                          : Column(
                              children: [
                                if (_previousPinnedComment != null)
                                  AnimatedPinnedComment(
                                    comment: _previousPinnedComment!,
                                    onDelete: _handleDeleteComment,
                                    isExiting: true,
                                  ),
                                if (_pinnedComment != null)
                                  AnimatedPinnedComment(
                                    key: ValueKey(_pinnedComment!.id),
                                    comment: _pinnedComment!,
                                    onDelete: _handleDeleteComment,
                                    onUnpin: () async {
                                      try {
                                        await _unpinComment(_pinnedComment!);
                                      } catch (e) {
                                        print('🔴 Error unpinning comment: $e');
                                      }
                                    },
                                    isEntering: _isTransitioning,
                                  ),
                                if (_pinnedComment == null && !_isTransitioning)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.purple.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.workspace_premium,
                                          color: Colors.purple.withOpacity(0.5),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Get the high score to pin your comment!',
                                          style: TextStyle(
                                            color: Colors.purple,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),

                    // Divider between pinned and regular comments
                    if (_pinnedComment != null)
                      const SliverToBoxAdapter(
                        child: Divider(height: 1),
                      ),

                    // Regular Comments
                    if (comments.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: Text('No comments yet')),
                      )
                    else
                      SliverAnimatedList(
                        initialItemCount: comments.length,
                        itemBuilder: (context, index, animation) {
                          final comment = comments[index];
                          final isCurrentUser = currentUser?.uid == comment.userId;

                          return SizeTransition(
                            sizeFactor: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: comment.userPhotoUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(comment.userPhotoUrl)
                                      : null,
                                  child: comment.userPhotoUrl.isEmpty
                                      ? Text(comment.userDisplayName[0].toUpperCase())
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      comment.userDisplayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat.yMMMd().format(comment.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (comment.wasPinned)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.workspace_premium,
                                          size: 16,
                                          color: Colors.purple.withOpacity(0.5),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(comment.text),
                                trailing: isCurrentUser
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _handleDeleteComment(comment),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),

          // Comment Input - Only show if user is logged in
          if (currentUser != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isSubmitting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _submitComment,
                        ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Please log in to comment',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 