class ApiConfig {
  // Update this with your machine's local IP address (e.g., 192.168.x.x) 
  // to connect from a real mobile device or emulator.
  static const String baseUrl = "http://10.83.12.106:8000"; // Your Wi-Fi IP: 10.83.12.106
  
  static const String uploadAadhaar = "$baseUrl/upload-aadhaar";
  static const String verifyFace = "$baseUrl/verify-face";
  static const String fetchAadhaarDirect = "$baseUrl/aadhaar-fetch-direct";
  static const String uploadOfflineXml = "$baseUrl/upload-offline-xml";
}
