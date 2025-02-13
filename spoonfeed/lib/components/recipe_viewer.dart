import 'package:flutter/material.dart';

class RecipeViewer extends StatefulWidget {
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final VoidCallback? onClose;

  const RecipeViewer({
    Key? key,
    required this.title,
    required this.ingredients,
    required this.steps,
    this.onClose,
  }) : super(key: key);

  @override
  _RecipeViewerState createState() => _RecipeViewerState();
}

class _RecipeViewerState extends State<RecipeViewer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.3, // Reduced height to fit better
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8), // More transparent to show video
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar for visual indication of recipe section
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Ingredients'),
              Tab(text: 'Steps'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Ingredients Tab
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.ingredients.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, 
                            size: 8, 
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.ingredients[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Steps Tab
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        itemCount: widget.steps.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentStep = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Step ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.steps[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Step Navigation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _currentStep > 0
                                ? () {
                                    setState(() {
                                      _currentStep--;
                                    });
                                  }
                                : null,
                          ),
                          Text(
                            '${_currentStep + 1}/${widget.steps.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, color: Colors.white),
                            onPressed: _currentStep < widget.steps.length - 1
                                ? () {
                                    setState(() {
                                      _currentStep++;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
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