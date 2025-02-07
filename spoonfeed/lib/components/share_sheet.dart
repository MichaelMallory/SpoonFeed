import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_model.dart';
import '../services/video/video_service.dart';

class ShareSheet extends StatefulWidget {
  final VideoModel video;
  final VideoService videoService;
  final Function(int) onShareCountUpdated;

  const ShareSheet({
    Key? key,
    required this.video,
    required this.videoService,
    required this.onShareCountUpdated,
  }) : super(key: key);

  @override
  _ShareSheetState createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  bool _isCopying = false;

  Future<void> _copyLink() async {
    setState(() => _isCopying = true);
    try {
      await Clipboard.setData(ClipboardData(text: widget.video.videoUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
      }
    } finally {
      setState(() => _isCopying = false);
    }
  }

  Future<void> _shareRecipe() async {
    final recipeText = '''
🍳 ${widget.video.title}

👨‍🍳 Recipe Details:
${widget.video.description}

Watch the full recipe video here:
${widget.video.videoUrl}

Shared via SpoonFeed - Your Cooking Companion
''';

    await Share.share(recipeText);
    widget.onShareCountUpdated(widget.video.shares + 1);
  }

  Future<void> _shareVideo() async {
    await Share.share(
      'Check out this amazing recipe on SpoonFeed: ${widget.video.videoUrl}',
      subject: widget.video.title,
    );
    widget.onShareCountUpdated(widget.video.shares + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Recipe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Share Options
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: const Text('Share Recipe Details'),
            subtitle: const Text('Share recipe with instructions'),
            onTap: _shareRecipe,
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library,
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: const Text('Share Video'),
            subtitle: const Text('Share video link only'),
            onTap: _shareVideo,
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isCopying ? Icons.check : Icons.link,
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: const Text('Copy Link'),
            subtitle: const Text('Copy video URL to clipboard'),
            onTap: _copyLink,
          ),

          // Social Platforms Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share to',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _SocialButton(
                      icon: Icons.message,
                      label: 'Messages',
                      onTap: () => _shareVideo(),
                    ),
                    _SocialButton(
                      icon: Icons.chat_bubble,
                      label: 'WhatsApp',
                      onTap: () => _shareVideo(),
                    ),
                    _SocialButton(
                      icon: Icons.facebook,
                      label: 'Facebook',
                      onTap: () => _shareVideo(),
                    ),
                    _SocialButton(
                      icon: Icons.send,
                      label: 'Telegram',
                      onTap: () => _shareVideo(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 