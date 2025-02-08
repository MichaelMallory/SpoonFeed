import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';

class PinnedCommentWidget extends StatelessWidget {
  final CommentModel comment;
  final VoidCallback? onDelete;
  final VoidCallback? onUnpin;

  const PinnedCommentWidget({
    Key? key,
    required this.comment,
    this.onDelete,
    this.onUnpin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with crown icon and "High Score"
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.purple,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'High Score: ${comment.gameScore}',
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // User info and comment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: comment.userPhotoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(comment.userPhotoUrl)
                    : null,
                child: comment.userPhotoUrl.isEmpty
                    ? Text(comment.userDisplayName[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.userDisplayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.yMMMd().format(comment.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (onUnpin != null)
                IconButton(
                  icon: const Icon(Icons.push_pin),
                  onPressed: onUnpin,
                  tooltip: 'Unpin comment',
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete comment',
                ),
            ],
          ),
        ],
      ),
    );
  }
} 