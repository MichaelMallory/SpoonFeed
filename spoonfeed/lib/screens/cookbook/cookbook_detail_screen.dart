import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cookbook_model.dart';
import '../../models/video_model.dart';
import '../../services/cookbook_service.dart';
import '../../components/video_card.dart';

class CookbookDetailScreen extends StatelessWidget {
  final CookbookModel cookbook;

  const CookbookDetailScreen({
    Key? key,
    required this.cookbook,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cookbookService = Provider.of<CookbookService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(cookbook.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cookbook.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                cookbook.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          Expanded(
            child: StreamBuilder<List<VideoModel>>(
              stream: cookbookService.getCookbookVideos(cookbook.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final videos = snapshot.data!;
                if (videos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No videos yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add videos by tapping the bookmark button\nwhile watching a video',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return Dismissible(
                      key: Key(video.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (direction) {
                        cookbookService.removeVideoFromCookbook(
                          cookbook.id,
                          video.id,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: VideoCard(
                          video: video,
                          onDismissed: () {
                            cookbookService.removeVideoFromCookbook(
                              cookbook.id,
                              video.id,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cookbook'),
        content: Text(
          'Are you sure you want to delete "${cookbook.name}"? '
          'This will remove all saved videos from this cookbook.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final cookbookService = Provider.of<CookbookService>(
        context,
        listen: false,
      );

      final success = await cookbookService.deleteCookbook(cookbook.id);
      if (success && context.mounted) {
        Navigator.pop(context);
      }
    }
  }
} 