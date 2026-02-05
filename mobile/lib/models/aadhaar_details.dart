class AadhaarDetails {
  final String uid;
  final String dob;
  final String gender;
  final String name;
  final String address;
  final String? photoPath;

  AadhaarDetails({
    required this.uid,
    required this.dob,
    required this.gender,
    required this.name,
    required this.address,
    this.photoPath,
  });

  factory AadhaarDetails.fromJson(dynamic json) {
    if (json == null) {
      return AadhaarDetails(uid: '', dob: '', gender: '', name: '', address: '');
    }

    // Safely extract the inner data map
    Map<String, dynamic> data;
    if (json is Map<String, dynamic>) {
      if (json.containsKey('details') && json['details'] is Map) {
        data = Map<String, dynamic>.from(json['details']);
      } else if (json.containsKey('data') && json['data'] is Map) {
        data = Map<String, dynamic>.from(json['data']);
      } else {
        data = json;
      }
    } else {
      data = {};
    }

    return AadhaarDetails(
      uid: (data['uid'] ?? data['aadhaar_number'] ?? '').toString(),
      dob: (data['dob'] ?? '').toString(),
      gender: (data['gender'] ?? '').toString(),
      name: (data['full_name'] ?? data['name'] ?? '').toString(),
      address: (data['address'] ?? data['full_address'] ?? '').toString(),
      photoPath: json is Map ? (json['aadhaar_photo'] ?? data['aadhaar_photo'])?.toString() : null,
    );
  }

}
