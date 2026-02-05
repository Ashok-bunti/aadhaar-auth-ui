import 'dart:io' show File;
import 'package:dio/dio.dart';

import 'package:camera/camera.dart';
import '../core/constants/api_config.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<Map<String, dynamic>> uploadAadhaar(List<int> bytes, String fileName) async {
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: fileName),
    });

    try {
      Response response = await _dio.post(ApiConfig.uploadAadhaar, data: formData);
      return response.data;
    } catch (e) {
      throw Exception("Failed to upload Aadhaar: $e");
    }
  }


  Future<Map<String, dynamic>> verifyFace(dynamic selfieSource, String aadhaarPath) async {
    MultipartFile multipartFile;
    
    if (selfieSource is XFile) {
      final bytes = await selfieSource.readAsBytes();
      multipartFile = MultipartFile.fromBytes(bytes, filename: selfieSource.name);
    } else if (selfieSource is File) {
      multipartFile = await MultipartFile.fromFile(selfieSource.path, filename: selfieSource.path.split('/').last);
    } else {
      throw Exception("Invalid selfie source");
    }


    FormData formData = FormData.fromMap({
      "live_file": multipartFile,
    });

    try {
      Response response = await _dio.post(
        "${ApiConfig.verifyFace}?aadhaar_path=${Uri.encodeComponent(aadhaarPath)}",
        data: formData,
      );
      return response.data;
    } catch (e) {
      throw Exception("Face verification failed: $e");
    }
  }


  Future<Map<String, dynamic>> fetchAadhaarDirect(String aadhaarNumber) async {
    try {
      Response response = await _dio.post(
        ApiConfig.fetchAadhaarDirect,
        data: {"aadhaar_number": aadhaarNumber},
      );
      return response.data;
    } catch (e) {
      throw Exception("Direct fetch failed: $e");
    }
  }

  Future<Map<String, dynamic>> uploadOfflineXml(List<int> bytes, String fileName, String password) async {
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: fileName),
      "password": password,
    });

    try {
      Response response = await _dio.post(ApiConfig.uploadOfflineXml, data: formData);
      return response.data;
    } catch (e) {
      throw Exception("Offline XML verification failed: $e");
    }
  }

}
