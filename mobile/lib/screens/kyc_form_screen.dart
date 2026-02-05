import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/aadhaar_details.dart';
import '../core/constants/api_config.dart';
import 'camera_screen.dart';

class KycFormScreen extends StatefulWidget {
  const KycFormScreen({super.key});

  @override
  State<KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends State<KycFormScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  AadhaarDetails? _extractedDetails;
  PlatformFile? _selectedFile;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _handleDirectFetch() async {
    final cleanUid = _uidController.text.replaceAll(' ', '');
    if (cleanUid.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 12-digit Aadhaar number")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _apiService.fetchAadhaarDirect(cleanUid);
      setState(() {
        _extractedDetails = AadhaarDetails.fromJson(res['data'] ?? res);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification Failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'pdf'],
      withData: !kIsWeb, // Get bytes on mobile as well for safety
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _handleOfflineXml() async {
    setState(() => _isLoading = true);
    try {
      final file = _selectedFile;
      if (file == null) {
        throw Exception("No file selected.");
      }

      List<int>? fileBytes;
      if (file.bytes != null) {
        fileBytes = file.bytes!.toList();
      } else if (!kIsWeb && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null) {
        throw Exception("The selected file could not be read. Please try picking it again.");
      }

      final res = await _apiService.uploadOfflineXml(
        fileBytes,
        file.name,
        _passwordController.text,
      );

      if (res == null) {
        throw Exception("The server returned no data. Check your connection.");
      }

      final details = AadhaarDetails.fromJson(res);
      
      setState(() {
        _extractedDetails = details;
      });
      
      debugPrint("Extracted Details: ${details.name}");
      debugPrint("Photo Path from Server: ${details.photoPath}");
    } catch (e, stack) {
      debugPrint("ERROR IN VERIFICATION: $e");
      debugPrint("STACKTRACE: $stack");
      
      String errorMsg = e.toString().contains('Null check operator') 
          ? "Data processing error. Please try a different file."
          : e.toString().replaceAll('Exception: ', '');
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Verification Failed: $errorMsg"),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Identity Verification"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 32),
            if (_extractedDetails == null) ...[
              const Text(
                "Verification Method",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose how you want to verify your identity today.",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              _buildTabControl(),
              const SizedBox(height: 32),
              SizedBox(
                height: 350,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDirectFetchForm(),
                    _buildOfflineXmlForm(),
                  ],
                ),
              ),
            ] else 
              _buildIdentityReview(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    bool isStep2 = _extractedDetails != null;
    return Row(
      children: [
        _stepCircle("1", "Input", true),
        _stepLine(isStep2),
        _stepCircle("2", "Review", isStep2),
        _stepLine(false),
        _stepCircle("3", "Face", false),
      ],
    );
  }

  Widget _stepCircle(String num, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3730A3) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: active ? const Color(0xFF3730A3) : Colors.grey.shade300, width: 2),
            boxShadow: active ? [BoxShadow(color: const Color(0xFF3730A3).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(color: active ? Colors.white : Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? const Color(0xFF1E293B) : Colors.grey.shade400)),
      ],
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
        color: active ? const Color(0xFF3730A3) : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildTabControl() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        labelColor: const Color(0xFF3730A3),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Quick Fetch"),
          Tab(text: "Offline XML"),
        ],
      ),
    );
  }

  Widget _buildDirectFetchForm() {
    return Column(
      children: [
        TextField(
          controller: _uidController,
          keyboardType: TextInputType.number,
          maxLength: 12,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2),
          decoration: const InputDecoration(
            counterText: "",
            labelText: "Aadhaar Card Number",
            hintText: "0000 0000 0000",
            prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
          ),
          onChanged: (val) {
            // Optional: Auto-format space logic could go here
          },
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "We will directly fetch your public information from the encrypted gateway.",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildActionButton(
          label: "Verify & Fetch Data",
          icon: Icons.bolt_outlined,
          onPressed: _handleDirectFetch,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildOfflineXmlForm() {
    return Column(
      children: [
        if (_selectedFile == null) ...[
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), shape: BoxShape.circle),
                    child: const Icon(Icons.upload_file_outlined, size: 32, color: Color(0xFF3730A3)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Select Aadhaar ZIP/PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text("Supported: .zip, .pdf", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ),
          ),
        ] else ...[
          _buildSelectedFileCard(),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: "Security PIN / Password",
              hintText: "Enter file password",
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B)),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
        ],
        const SizedBox(height: 40),
        _buildActionButton(
          label: "Decrypt & Verify",
          icon: Icons.verified_user_outlined,
          onPressed: _handleOfflineXml,
          isLoading: _isLoading,
          enabled: _selectedFile != null,
        ),
      ],
    );
  }

  Widget _buildSelectedFileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedFile!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534))),
                Text("${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB", style: TextStyle(fontSize: 12, color: const Color(0xFF166534).withOpacity(0.7))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            onPressed: () => setState(() => _selectedFile = null),
          )
        ],
      ),
    );
  }

  Widget _buildIdentityReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Review Your Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        const Text("Verify that the information extracted below matches your official identity card.", style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 32),
        _buildProfessionalIDCard(),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _extractedDetails = null),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 58),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Reset", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CameraScreen(details: _extractedDetails!)));
                },
                child: const Text("Next Step"),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildProfessionalIDCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF3730A3),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("AUTHENTICATED IDENTITY DOCUMENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhotoAvatar(),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Aadhaar Number", style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            Text(_extractedDetails!.uid, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: 1)),
                            const SizedBox(height: 16),
                            _idField("Name", _extractedDetails!.name),
                            _idField("Date of Birth", _extractedDetails!.dob),
                            _idField("Gender", _extractedDetails!.gender),
                          ],
                        ),
                      )
                    ],
                  ),
                  const Divider(height: 48),
                  _idField("Address", _extractedDetails!.address, fullWidth: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoAvatar() {
    String? photoPath = _extractedDetails?.photoPath;
    ImageProvider? imageProvider;

    if (photoPath != null && photoPath.isNotEmpty && !photoPath.contains('placehold.co')) {
      if (photoPath.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(photoPath.split(',').last));
      } else {
        String fullUrl = photoPath.startsWith('http') 
            ? photoPath 
            : "${ApiConfig.baseUrl}${photoPath.startsWith('/') ? '' : '/'}$photoPath";
        imageProvider = NetworkImage(fullUrl);
      }
    }

    return Container(
      width: 100,
      height: 125,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: imageProvider != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF94A3B8)));
                },
              ),
            )
          : const Center(child: Icon(Icons.person, size: 48, color: Color(0xFFCBD5E1))),
    );
  }

  Widget _idField(String label, String value, {bool fullWidth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onPressed, bool isLoading = false, bool enabled = true}) {
    return ElevatedButton.icon(
      onPressed: (isLoading || !enabled) ? null : onPressed,
      icon: isLoading 
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 20),
      label: Text(label),
    );
  }
}
