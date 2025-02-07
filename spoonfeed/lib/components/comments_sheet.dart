import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';
import '../services/video/video_service.dart';

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCommentCount;
  final VideoService videoService;
  final Function(int) onCommentCountUpdated;

  const CommentsSheet({
    Key? key,
    required this.videoId,
    required this.initialCommentCount,
    required this.videoService,
    required this.onCommentCountUpdated,
  }) : super(key: key);

  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await widget.videoService.getVideoComments(widget.videoId);
      setState(() {
        _comments = comments.map((doc) => CommentModel.fromMap(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comments: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load comments')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final comment = await widget.videoService.addComment(
        widget.videoId,
        text,
      );

      if (comment != null) {
        setState(() {
          _comments.insert(0, CommentModel.fromMap(comment));
          _commentController.clear();
          widget.onCommentCountUpdated(_comments.length);
        });
      }

      // Scroll to top to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error submitting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    try {
      final success = await widget.videoService.deleteComment(
        widget.videoId,
        comment.id,
      );

      if (success) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
          widget.onCommentCountUpdated(_comments.length);
        });
      }
    } catch (e) {
      print('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header
          Container(
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
                  'Comments (${widget.initialCommentCount})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == comment.userId;

                          return ListTile(
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
                              ],
                            ),
                            subtitle: Text(comment.text),
                            trailing: isCurrentUser
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteComment(comment),
                                  )
                                : null,
                          );
                        },
                      ),
          ),

          // Comment Input
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
          ),
        ],
      ),
    );
  }
} 