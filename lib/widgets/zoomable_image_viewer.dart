import 'dart:io';
import 'package:flutter/material.dart';

/// Shows a full-screen interactive zoomable image viewer with pinch-to-zoom and double-tap zoom.
void showZoomableImageViewer(
  BuildContext context, {
  required String imagePath,
  String? title,
}) {
  if (imagePath.isEmpty || !File(imagePath).existsSync()) return;

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.9),
    builder: (ctx) => ZoomableImageViewerDialog(
      imagePath: imagePath,
      title: title,
    ),
  );
}

class ZoomableImageViewerDialog extends StatefulWidget {
  final String imagePath;
  final String? title;

  const ZoomableImageViewerDialog({
    Key? key,
    required this.imagePath,
    this.title,
  }) : super(key: key);

  @override
  State<ZoomableImageViewerDialog> createState() =>
      _ZoomableImageViewerDialogState();
}

class _ZoomableImageViewerDialogState
    extends State<ZoomableImageViewerDialog> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  AnimationController? _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final Matrix4 currentMatrix = _transformationController.value;

    // Check if zoomed in
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix;
    if (currentScale > 1.2) {
      // Zoom out to normal
      targetMatrix = Matrix4.identity();
    } else {
      // Zoom in 2.5x centered at tap position
      const double targetScale = 2.5;
      final double x = -position.dx * (targetScale - 1);
      final double y = -position.dy * (targetScale - 1);

      targetMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(targetScale);
    }

    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurveTween(curve: Curves.fastOutSlowIn).animate(_animationController!));

    _animationController!.forward(from: 0.0);
  }

  void _resetZoom() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController!));

    _animationController!.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dismiss background tap
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),

          // Zoomable Image
          Center(
            child: GestureDetector(
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformationController,
                clipBehavior: Clip.none,
                minScale: 0.5,
                maxScale: 5.0,
                child: Hero(
                  tag: 'zoomable_image_${widget.imagePath}',
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.title != null && widget.title!.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(width: 12),
                Row(
                  children: [
                    // Reset zoom button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_out_map_rounded,
                            color: Colors.white, size: 20),
                      ),
                      onPressed: _resetZoom,
                      tooltip: 'Reset Zoom',
                    ),
                    const SizedBox(width: 6),
                    // Close button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Hint Toast
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        color: Colors.white70, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Pinch or double-tap to zoom',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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
