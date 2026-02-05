import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../models/aadhaar_details.dart';
import '../services/api_service.dart';
import 'dart:io';

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
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to form
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
    return Positioned.fill(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.srcOut),
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
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      top: 150,
      left: 0,
      right: 0,
      child: Column(
        children: [
          const Text("Live Face Verification", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: const Text("Keep your head within the frame", style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
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
          border: Border.all(color: Colors.white, width: 4),
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
