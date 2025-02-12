import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/video_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  XFile? _videoFile;
  VideoPlayerController? _controller;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final VideoService _videoService;

  @override
  void initState() {
    super.initState();
    _videoService = VideoService();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10), // Limit video length
    );
    
    if (video != null) {
      setState(() {
        _videoFile = video;
      });
      
      if (kIsWeb) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(video.path))
          ..initialize().then((_) {
            setState(() {});
            _controller?.play(); // Auto-play preview
          });
      } else {
        _controller = VideoPlayerController.file(File(video.path))
          ..initialize().then((_) {
            setState(() {});
            _controller?.play(); // Auto-play preview
          });
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      if (kIsWeb) {
        // Handle web upload
        final bytes = await _videoFile!.readAsBytes();
        
        // Check file size (100MB limit)
        if (bytes.length > 100 * 1024 * 1024) {
          throw Exception('File size exceeds 100MB limit');
        }

        await _videoService.uploadVideoWeb(
          videoBytes: bytes,
          fileName: _videoFile!.name,
          title: _titleController.text,
          description: _descriptionController.text,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
      } else {
        // Handle mobile upload
        final file = File(_videoFile!.path);
        
        // Check file size (100MB limit)
        if (await file.length() > 100 * 1024 * 1024) {
          throw Exception('File size exceeds 100MB limit');
        }

        await _videoService.uploadVideo(
          videoFile: file,
          title: _titleController.text,
          description: _descriptionController.text,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Recipe Video'),
        actions: [
          if (_videoFile != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _uploadVideo,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _uploadProgress > 0
                        ? 'Uploading video... ${(_uploadProgress * 100).toStringAsFixed(1)}%'
                        : 'Preparing upload...',
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_videoFile == null) ...[
                    AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: _pickVideo,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library, size: 64),
                              SizedBox(height: 16),
                              Text('Tap to select a recipe video'),
                              SizedBox(height: 8),
                              Text(
                                'Maximum duration: 10 minutes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    if (_controller?.value.isInitialized ?? false) ...[
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller!),
                            IconButton(
                              icon: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 48,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller!.value.isPlaying
                                      ? _controller!.pause()
                                      : _controller!.play();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Recipe Title',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Easy Homemade Pizza',
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Recipe Description',
                              border: OutlineInputBorder(),
                              hintText: 'Share the ingredients and steps...',
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
} 