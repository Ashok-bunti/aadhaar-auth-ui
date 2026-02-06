import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // Added for TapGestureRecognizer
import 'package:google_fonts/google_fonts.dart'; 
import 'package:url_launcher/url_launcher.dart';
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
  final _uidController = TextEditingController();
  final _passwordController = TextEditingController(); // For XML/PDF password
  
  File? _selectedFile;
  String? _selectedFileName;
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  AadhaarDetails? _extractedDetails;
  
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// ACTION HANDLERS
  /// --------------------------------------------------------------------------

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'zip', 'pdf'],
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
             // Web handling if needed
          } else {
            _selectedFile = File(result.files.single.path!);
          }
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint("File picker error: $e");
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    
    try {
      AadhaarDetails? details;
      
      // 1. Direct UID Fetch
      if (_tabController.index == 0) {
        // Validation
        if (_uidController.text.length != 12) {
          throw Exception("Please enter a valid 12-digit Aadhaar number");
        }
        // details = await _apiService.fetchAadhaarDirect(_uidController.text);
        throw Exception("Direct fetch is currently disabled for demo. Please use Offline XML.");
      } 
      // 2. Offline XML/PDF
      else {
        if (_selectedFile == null) throw Exception("Please upload a file");
        if (_passwordController.text.isEmpty) throw Exception("Please enter the file password");

        // Read file bytes
        final bytes = await _selectedFile!.readAsBytes();

        final responseMap = await _apiService.uploadOfflineXml(
          bytes, 
          _selectedFileName!,
          _passwordController.text
        );
        
        details = AadhaarDetails.fromJson(responseMap);
      }

      if (details == null) throw Exception("Failed to verify Aadhaar details");

      setState(() {
        _extractedDetails = details;
      });
    } catch (e) {
      String errorMsg = e.toString().contains('Exception:') 
          ? e.toString().replaceAll('Exception: ', '')
          : "Verification failed. Please check inputs.";
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// --------------------------------------------------------------------------
  /// UI BUILDERS
  /// --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_extractedDetails != null) {
      return _buildIdentityReview(); 
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background, // F8FAFC
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              // 1. Bar Indicator Removed

              // 2. Titles
              Text(
                "Identity Verification",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700, // Extra Bold
                  color: const Color(0xFF111827), // Gray 900
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose your preferred verification method",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF6B7280), // Gray 500
                ),
              ),
              const SizedBox(height: 32),

              // 3. Tab Pills
              _buildTabControl(),
              const SizedBox(height: 32),

              // 4. Tab Content
              SizedBox(
                height: 500, // Fixed height for form content
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDirectFetchForm(),
                    _buildOfflineXmlForm(),
                  ],
                ),
              ),

              // 5. Footer (Security)
              _buildSecurityFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildBarIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor, // Active Blue
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB), // Inactive Grey
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildTabControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // Gray 100
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: "Aadhaar Number"),
          Tab(text: "Offline XML"),
        ],
      ),
    );
  }


  Widget _buildDirectFetchForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Aadhaar Number"),
        TextField(
          controller: _uidController,
          keyboardType: TextInputType.number,
          style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w500),
          decoration: _inputDecoration("0000 0000 0000"),
        ),
        const SizedBox(height: 24),
        _actionButton("Fetch Identity Details", Icons.shield_outlined, _handleSubmit,
          isLoading: _isLoading,
          isPrimary: false), // Disabled/Secondary look as it's not the main flow usually
      ],
    );
  }

  Widget _buildOfflineXmlForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper Link
        Row(
          children: [
             Expanded(
               child: RichText(
                 text: TextSpan(
                   style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF374151)),
                   children: [
                     TextSpan(text: "E-Aadhaar: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))), // Red
                     const TextSpan(text: "Visit "),
                     TextSpan(
                       text: "myaadhaar.uidai.gov.in",
                       style: TextStyle(
                         color: Theme.of(context).primaryColor, 
                         fontWeight: FontWeight.w600,
                         decoration: TextDecoration.underline
                       ),
                       recognizer: TapGestureRecognizer()..onTap = () async {
                         final Uri url = Uri.parse("https://myaadhaar.uidai.gov.in"); 
                         if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            debugPrint("Could not launch \$url");
                         }
                       },
                     ),
                     const TextSpan(text: " to download your ZIP file"),
                   ],
                 ),
               ),
             )
          ],
        ),
        const SizedBox(height: 20),

        _label("Upload PDF File"),
        _buildFileUpload(),
        const SizedBox(height: 20),

        _label("Password"),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: _inputDecoration("e.g., AAAA1234").copyWith(
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text("Format: First 4 letters of your name (uppercase) + Birth Year (YYYY)", 
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280))),
        
        const SizedBox(height: 24),
        
        _actionButton("Verify Offline e-KYC", Icons.verified_user_outlined, _handleSubmit,
          isLoading: _isLoading,
          isPrimary: true),
      ],
    );
  }
  
  Widget _buildFileUpload() {
    if (_selectedFile != null) {
      // FILLED STATE (Green Box)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5), // Mint Green Light
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1), // Dashed green essentially
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5), // Darker Mint
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description, color: Color(0xFF047857)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedFileName ?? "file.pdf",
                style: GoogleFonts.inter(
                  color: const Color(0xFF047857), // Dark Green text
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
              onPressed: _removeFile,
            )
          ],
        ),
      );
    }

    // EMPTY STATE (Dashed Box simulation)
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        height: 120, // Taller
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1, style: BorderStyle.solid), // Standard border for now
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload_file, size: 28, color: Color(0xFF64748B)),
              const SizedBox(height: 12),
              Text(
                "Click to Browse PDF",
                style: GoogleFonts.inter(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
    );
  }

  Widget _actionButton(String text, IconData icon, VoidCallback onTap, {required bool isLoading, required bool isPrimary}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Theme.of(context).primaryColor : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.security, size: 16, color: Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text("End-to-End Encryption Enabled", style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // NOTE: Simple Review Screen (kept mostly functional/same just updating header if needed)
  Widget _buildIdentityReview() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: (){ setState(() => _extractedDetails = null); }), title: const Text("Review Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Row indicators 
            // Row indicators removed
            const SizedBox(height: 32),
            _buildReviewContent()
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(details: _extractedDetails!)));
            },
            child: const Text("Proceed to Face Verification"),
          ),
        ),
      ),
    );
  }
  
  Widget _buildReviewContent() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Main Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Photo & Name
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade50,
                      ),
                      child: ClipRRect(
                         borderRadius: BorderRadius.circular(7),
                         child: _extractedDetails!.photoPath != null
                            ? Image(image: _getPhotoProvider(), fit: BoxFit.cover)
                            : const Center(child: Icon(Icons.person, color: Colors.grey, size: 40)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        _extractedDetails!.name, 
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                
                // Right: Details (DOB, Gender, Address)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                               _cardLabel("DOB"),
                               Text(_extractedDetails!.dob, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            ]),
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                               _cardLabel("Gender"),
                               Text(_extractedDetails!.gender, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      _cardLabel("Address"),
                      Text(
                        _extractedDetails!.address,
                        style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.black87)
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          
          // Bottom: Aadhaar Number
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
               color: Color(0xFFF9FAFB), // Very Light Grey
               borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Center(
              child: Text(
                _formatAadhaarBox(_extractedDetails!.uid),
                style: GoogleFonts.sourceCodePro(
                  fontSize: 18, 
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: const Color(0xFF111827) // Dark Grey/Black
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardLabel(String text) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 2),
       child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280))),
     );
  }

  Widget _realCardField(String label, String value, {bool isBold = false}) {
    // Deprecated, using new layout above
    return const SizedBox.shrink();
  }

  String _formatAadhaarBox(String uid) {
    if (uid.length != 12) return uid;
    return "${uid.substring(0,4)} ${uid.substring(4,8)} ${uid.substring(8,12)}";
  }
  
  ImageProvider _getPhotoProvider() {
     // Trust photoPath first
     if (_extractedDetails!.photoPath != null && _extractedDetails!.photoPath!.isNotEmpty) {
        if (_extractedDetails!.photoPath!.startsWith('http')) {
           return NetworkImage(_extractedDetails!.photoPath!);
        } else if (_extractedDetails!.photoPath!.length > 200) {
           // Probably a base64 string
           String cleanBase64 = _extractedDetails!.photoPath!.replaceAll(RegExp(r'\s+'), '');
           if (cleanBase64.contains(',')) {
             cleanBase64 = cleanBase64.split(',').last;
           }
           try {
             return MemoryImage(base64Decode(cleanBase64));
           } catch (e) {
             debugPrint("Error decoding base64: $e");
             return const AssetImage('assets/logo.png');
           }
        }
     }
     return const AssetImage('assets/logo.png'); // Fallback
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(flex: 3, child: Text(value ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

// Helper for Dashed Border
class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF94A3B8) // Slate 400
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final Path path = Path();
    // Simple dashed border implementation
    double dashWidth = 5;
    double dashSpace = 3;
    double startX = 0;
    
    // Top line
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
    
    // Right line
    double startY = 0;
     while (startY < size.height) {
      canvas.drawLine(Offset(size.width, startY), Offset(size.width, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
    
    // Bottom line
    startX = size.width;
    while (startX > 0) {
      canvas.drawLine(Offset(startX, size.height), Offset(startX - dashWidth, size.height), paint);
      startX -= dashWidth + dashSpace;
    }
    
    // Left line
    startY = size.height;
    while (startY > 0) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY - dashWidth), paint);
      startY -= dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
