import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  bool get _isLocalFile => imageUrl.startsWith('/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: const Text('View Image', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag,
            child: _isLocalFile
                ? Image.file(
                    File(imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text('Failed to load image.', style: TextStyle(color: Colors.white)),
                      );
                    },
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text('Failed to load image.', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
