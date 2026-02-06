import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import '../models/aadhaar_details.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'kyc_form_screen.dart';

class CameraScreen extends StatefulWidget {
  final AadhaarDetails details;
  const CameraScreen({super.key, required this.details});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  XFile? _capturedImage;
  Uint8List? _webImageBytes;
  bool _isVerifying = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isEmpty) return;
    
    _controller = CameraController(
      _cameras!.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => _cameras!.first),
      ResolutionPreset.high, // Better quality
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await image.readAsBytes();
      }

      setState(() {
        _capturedImage = image;
        _webImageBytes = bytes;
        _isVerifying = true;
      });

      final result = await _apiService.verifyFace(
        image, 
        widget.details.photoPath ?? ""
      );

      _showResultDialog(result['verified'] ?? false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Biometric Error: $e")));
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showResultDialog(bool verified) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: verified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    verified ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: verified ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  verified ? "Identity Verified" : "Verification Failed",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Text(
                  verified 
                    ? "Your biometric profile matches your Aadhaar identity successfully." 
                    : "The live photo did not match the Aadhaar record. Please try again in better lighting.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                     // Close dialog and navigate back to the clean form (resetting state)
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const KycFormScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text("Done"),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Surface
          Positioned.fill(
            child: _capturedImage == null 
              ? CameraPreview(_controller!)
              : (kIsWeb 
                  ? Image.memory(_webImageBytes!, fit: BoxFit.cover) 
                  : Image.file(File(_capturedImage!.path), fit: BoxFit.cover)),
          ),
          
          // Professional Overlay
          if (_capturedImage == null) ...[
            _buildBiometricOverlay(),
            _buildInstructions(),
          ],

          // App Bar Area (Custom)
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Action Button Area
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: _capturedImage == null 
                ? _captureButton() 
                : _retakeControls(),
            ),
          ),

          // Verifying Loader
          if (_isVerifying)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    SizedBox(height: 24),
                    Text("SECURE BIOMETRIC ANALYSIS...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildBiometricOverlay() {
    return Stack(
      children: [
        // Darkened Background with Face Hole
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.8), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 380,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(140),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Dotted Border (Green & Red)
        Center(
        // Dotted Border Removed
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      top: 100, // Moved up
      left: 0,
      right: 0,
      child: Column(
        children: [
          const Text(
            "Face Verification",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 30),
          
          // Instruction Chips
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _instructionChip(Icons.wb_sunny_outlined, "Bright lighting"),
              _instructionChip(Icons.face, "Remove glasses"),
              _instructionChip(Icons.remove_red_eye_outlined, "Blink eyes"),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _instructionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      onTap: _captureAndVerify,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.greenAccent, width: 4), // Green Accent for action
          boxShadow: [
             BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
          ]
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.camera_alt, color: Colors.black, size: 32),
        ),
      ),
    );
  }

  Widget _retakeControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Analysing captured frame...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => setState(() => _capturedImage = null),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text("Retake Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// Custom Painter for Dotted Border
class DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF22C55E) // Green 500 by default
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(145),
      ));

    // Draw green dashed line
    drawDashedPath(canvas, path, paint, dashWidth: 10, dashSpace: 8);
    
    // Draw Red corners for visual flair (as requested "green and red")
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEF4444) // Red 500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
      
      // Top Left Corner
      canvas.drawArc(
         Rect.fromLTWH(0, 0, 60, 60), 
         math.pi, 
         math.pi/2, 
         false, 
         redPaint
      );
      // Top Right
      canvas.drawArc(
         Rect.fromLTWH(size.width - 60, 0, 60, 60), 
         3 * math.pi / 2, 
         math.pi/2, 
         false, 
         redPaint
      );
      // Bottom Corners
      canvas.drawArc(Rect.fromLTWH(0, size.height - 60, 60, 60), math.pi/2, math.pi/2, false, redPaint);
      canvas.drawArc(Rect.fromLTWH(size.width - 60, size.height - 60, 60, 60), 0, math.pi/2, false, redPaint);
  }
  
  void drawDashedPath(Canvas canvas, Path path, Paint paint, {double dashWidth = 10, double dashSpace = 5}) {
    // Simple implementation for dashing
    var metrics = path.computeMetrics();
    for (var metric in metrics) {
      double start = 0;
      while (start < metric.length) {
        // Draw green dashes only in the "middle" sections, avoiding the corners which are red
        // This is complex so simplified: Just draw dashed green everywhere, red on top
        // But to avoid overlap, we stick to green dashes.
         canvas.drawPath(
            metric.extractPath(start, start + dashWidth),
            paint,
         );
         start += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
