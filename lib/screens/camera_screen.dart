import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isStable = false;
  int _stabilityCount = 0;
  static const int _stabilityThreshold = 20; // ~2s at 10fps stability checks

  late AnimationController _pulseController;
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;
  Timer? _stabilityTimer;
  Timer? _autoSnapTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _borderAnimation = CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeInOut,
    );

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
        _startStabilityDetection();
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

  void _startStabilityDetection() {
    _stabilityTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _isCapturing) return;

      // Increment stability count — in a real gyroscope impl, this would
      // check accelerometer delta. Here we simulate with a simple counter.
      _stabilityCount++;

      if (_stabilityCount >= _stabilityThreshold && !_isStable) {
        setState(() => _isStable = true);
        _borderController.forward();
        // Auto-snap after 1.5 seconds of stability
        _autoSnapTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted && _isStable && !_isCapturing) {
            _captureImage();
          }
        });
      }
    });
  }

  Future<void> _captureImage() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);
    _stabilityTimer?.cancel();
    _autoSnapTimer?.cancel();

    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, photo);
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

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _autoSnapTimer?.cancel();
    _pulseController.dispose();
    _borderController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Starting camera...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

          // Dark overlay with card-shaped transparent cutout
          if (_isInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: _CardOverlayPainter(
                  isStable: _isStable,
                  stabilityProgress: _borderAnimation,
                  pulseAnimation: _pulseController,
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isStable
                              ? Colors.green.withOpacity(0.3 + 0.4 * _pulseController.value)
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isStable ? Colors.green : Colors.white30,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isStable ? Icons.check_circle : Icons.crop_free,
                              color: _isStable ? Colors.green : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isStable ? 'Ready!' : 'Align card in frame',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
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
                          : _isStable
                              ? 'Auto-capturing...'
                              : 'Position card within the frame',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Shutter button
                    GestureDetector(
                      onTap: _isCapturing ? null : _captureImage,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing
                                  ? Colors.grey
                                  : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(
                                    _isStable ? 0.4 * _pulseController.value : 0.2,
                                  ),
                                  blurRadius: _isStable ? 20 : 10,
                                  spreadRadius: _isStable ? 8 : 4,
                                ),
                              ],
                            ),
                            child: _isCapturing
                                ? const Center(
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.camera_alt, color: Colors.black, size: 32),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to capture manually',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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
  final bool isStable;
  final Animation<double> stabilityProgress;
  final Animation<double> pulseAnimation;

  _CardOverlayPainter({
    required this.isStable,
    required this.stabilityProgress,
    required this.pulseAnimation,
  }) : super(repaint: Listenable.merge([stabilityProgress, pulseAnimation]));

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

    // Card border / corner guides
    final borderColor = isStable
        ? Color.lerp(Colors.white54, Colors.greenAccent, stabilityProgress.value)!
        : Colors.white54;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isStable ? 2.5 : 2.0;

    // Draw corner brackets
    const cornerLen = 28.0;
    final corners = [
      [cardLeft, cardTop, 1.0, 1.0],   // top-left
      [cardLeft + cardWidth, cardTop, -1.0, 1.0],  // top-right
      [cardLeft, cardTop + cardHeight, 1.0, -1.0], // bottom-left
      [cardLeft + cardWidth, cardTop + cardHeight, -1.0, -1.0], // bottom-right
    ];

    for (final corner in corners) {
      final cx = corner[0];
      final cy = corner[1];
      final dx = corner[2];
      final dy = corner[3];

      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cornerLen * dx, cy),
        borderPaint,
      );
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx, cy + cornerLen * dy),
        borderPaint,
      );
    }

    // Stable glow effect
    if (isStable && stabilityProgress.value > 0.1) {
      final glowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.15 * stabilityProgress.value)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(cardRect, glowPaint);

      final glowBorderPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.6 * stabilityProgress.value)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(cardRect, glowBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter oldDelegate) {
    return oldDelegate.isStable != isStable;
  }
}
