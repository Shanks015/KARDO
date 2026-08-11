import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;

  bool _isBatchMode = false;
  bool _isFlashOn = false;
  final List<XFile> _batchPhotos = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera found on this device')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Use rear camera
      final rear = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _captureImage() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      
      // Crop image to the frame
      try {
        final bytes = await File(photo.path).readAsBytes();
        final imageRaw = img.decodeImage(bytes);
        if (imageRaw != null) {
          final image = img.bakeOrientation(imageRaw);
          final imgW = image.width;
          final imgH = image.height;
          
          final cropW = (imgW * 0.88).round();
          final cropH = (cropW / 1.586).round();
          final cropX = ((imgW - cropW) / 2).round();
          final cropY = ((imgH - cropH) / 2 - imgH * 0.04).round();
          
          final safeX = cropX.clamp(0, imgW);
          final safeY = cropY.clamp(0, imgH);
          final safeW = cropW.clamp(0, imgW - safeX);
          final safeH = cropH.clamp(0, imgH - safeY);
          final cropped = img.copyCrop(image, x: safeX, y: safeY, width: safeW, height: safeH);
          img.Image finalImage = cropped;
          if (cropped.width > 1200) {
            finalImage = img.copyResize(cropped, width: 1200);
          }
          final croppedBytes = img.encodeJpg(finalImage, quality: 85);
          await File(photo.path).writeAsBytes(croppedBytes);
        }
      } catch (e) {
        debugPrint('Crop failed: $e');
      }

      if (mounted) {
        if (_isBatchMode) {
          setState(() {
            _batchPhotos.add(photo);
            _isCapturing = false;
          });
        } else {
          Navigator.pop(context, photo);
        }
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashOn = true);
      }
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.width,
                height: size.width * _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Dark overlay with card-shaped transparent cutout
          if (_isInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: _CardOverlayPainter(),
              ),
            ),

          // Top bar and toggle
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                      ),
                      IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Mode Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isBatchMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isBatchMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Single Mode',
                            style: TextStyle(
                              color: !_isBatchMode ? const Color(0xFF536DFE) : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBatchMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isBatchMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Batch Mode',
                            style: TextStyle(
                              color: _isBatchMode ? const Color(0xFF536DFE) : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text(
                      _isCapturing
                          ? 'Processing...'
                          : 'Position card within the frame',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _isCapturing ? null : _captureImage,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  color: Colors.transparent,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isCapturing ? Colors.grey : Colors.white,
                                    ),
                                    child: _isCapturing
                                        ? const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.black,
                                                strokeWidth: 2.5,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isBatchMode && _batchPhotos.isNotEmpty)
                          Positioned(
                            right: 0,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(context, _batchPhotos),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: Text('Done (${_batchPhotos.length})'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF536DFE),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                      ],
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

/// Custom painter that draws a semi-transparent overlay with a card-shaped cutout
class _CardOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Card dimensions: standard business card ratio is 85.6mm x 54mm (≈ 1.586:1)
    final cardWidth = size.width * 0.88;
    final cardHeight = cardWidth / 1.586;
    final cardLeft = (size.width - cardWidth) / 2;
    final cardTop = (size.height - cardHeight) / 2 - size.height * 0.04;

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(12),
    );

    // Semi-transparent overlay outside the card
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cardRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Clean white border based on the mockup
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    // Draw rounded rect border for the card
    canvas.drawRRect(cardRect, borderPaint);

    // Draw little white corner dots (mockup style)
    final cornerPaint = Paint()..color = Colors.white;
    const dotRadius = 4.0;
    canvas.drawCircle(Offset(cardLeft, cardTop), dotRadius, cornerPaint);
    canvas.drawCircle(Offset(cardLeft + cardWidth, cardTop), dotRadius, cornerPaint);
    canvas.drawCircle(Offset(cardLeft, cardTop + cardHeight), dotRadius, cornerPaint);
    canvas.drawCircle(Offset(cardLeft + cardWidth, cardTop + cardHeight), dotRadius, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter oldDelegate) {
    return false;
  }
}
