import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _error;

  bool get _isLocalFile => widget.videoUrl.startsWith('/');

  @override
  void initState() {
    super.initState();
    _controller = _isLocalFile
        ? VideoPlayerController.file(File(widget.videoUrl))
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() {
        _isInitialized = true;
      });
      _controller.play();
    }).catchError((e) {
      setState(() {
        _error = 'Error loading video: $e';
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: const Text('View Video', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : _isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                      _ControlsOverlay(controller: _controller),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: AppColors.primary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  const _ControlsOverlay({required this.controller});

  @override
  State<_ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<_ControlsOverlay> {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.controller.value.isPlaying
          ? GestureDetector(
              onTap: () {
                widget.controller.pause();
                setState(() {});
              },
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            )
          : Container(
              color: Colors.black38,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.play_arrow_rounded, size: 64, color: Colors.white),
                  onPressed: () {
                    widget.controller.play();
                    setState(() {});
                  },
                ),
              ),
            ),
    );
  }
}
