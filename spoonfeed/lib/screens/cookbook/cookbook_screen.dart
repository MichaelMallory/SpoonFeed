import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cookbook_model.dart';
import '../../services/cookbook_service.dart';
import 'cookbook_detail_screen.dart';

class CookbookScreen extends StatelessWidget {
  const CookbookScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cookbookService = Provider.of<CookbookService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookbook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateCookbookDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<CookbookModel>>(
        stream: cookbookService.getUserCookbooks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cookbooks = snapshot.data!;
          if (cookbooks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No cookbooks yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showCreateCookbookDialog(context),
                    child: const Text('Create Cookbook'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cookbooks.length,
            itemBuilder: (context, index) {
              final cookbook = cookbooks[index];
              return _CookbookCard(cookbook: cookbook);
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateCookbookDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Cookbook'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter cookbook name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter cookbook description',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final cookbookService = Provider.of<CookbookService>(
                context,
                listen: false,
              );

              final cookbook = await cookbookService.createCookbook(
                name: name,
                description: descriptionController.text.trim(),
              );

              if (cookbook != null && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _CookbookCard extends StatelessWidget {
  final CookbookModel cookbook;

  const _CookbookCard({
    Key? key,
    required this.cookbook,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CookbookDetailScreen(cookbook: cookbook),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cookbook.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${cookbook.videoCount} videos',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
              if (cookbook.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  cookbook.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 