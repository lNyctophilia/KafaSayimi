import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? heroTag;

  const FullScreenImageViewer({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.heroTag,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final scale = _controller.value.getMaxScaleOnAxis();
      if ((scale - _currentScale).abs() > 0.05) {
        setState(() {
          _currentScale = scale;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_controller.value != Matrix4.identity()) {
      setState(() {
        _controller.value = Matrix4.identity();
        _currentScale = 1.0;
      });
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * 1.5;
      final y = -position.dy * 1.5;
      final zoomed = Matrix4.identity()
        ..translateByDouble(x, y, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
      setState(() {
        _controller.value = zoomed;
        _currentScale = 2.5;
      });
    }
  }

  void _zoomIn() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.4).clamp(0.5, 8.0);
    final ratio = newScale / currentScale;
    setState(() {
      _controller.value = _controller.value.scaledByDouble(ratio, ratio, 1.0, 1.0);
      _currentScale = newScale;
    });
  }

  void _zoomOut() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.4).clamp(0.5, 8.0);
    final ratio = newScale / currentScale;
    setState(() {
      _controller.value = _controller.value.scaledByDouble(ratio, ratio, 1.0, 1.0);
      _currentScale = newScale;
    });
  }

  void _resetZoom() {
    setState(() {
      _controller.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (widget.imageBytes != null) {
      imageWidget = Image.memory(
        widget.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text(
            'Görüntü yüklenemedi',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    } else if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      if (kIsWeb) {
        imageWidget = Image.network(
          widget.imagePath!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Text(
              'Görüntü yüklenemedi',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      } else {
        imageWidget = Image.file(
          File(widget.imagePath!),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Text(
              'Görüntü yüklenemedi',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      }
    } else {
      imageWidget = const Center(
        child: Text(
          'Görüntü bulunamadı',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Görüntü İnceleme (${(_currentScale * 100).round()}%)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_currentScale != 1.0)
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Yakınlaştırmayı Sıfırla',
              onPressed: _resetZoom,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Zoomable & Pannable View
          GestureDetector(
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 8.0,
              boundaryMargin: const EdgeInsets.all(200),
              clipBehavior: Clip.none,
              child: Center(
                child: imageWidget,
              ),
            ),
          ),

          // Bottom Control Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                      tooltip: 'Uzaklaştır',
                      onPressed: _zoomOut,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_rounded, color: Colors.white),
                      tooltip: 'Ekrana Sığdır',
                      onPressed: _resetZoom,
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                      tooltip: 'Yakınlaştır',
                      onPressed: _zoomIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
