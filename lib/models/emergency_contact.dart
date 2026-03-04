class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
    );
  }

  factory EmergencyContact.create({
    required String name,
    required String phoneNumber,
  }) {
    return EmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phoneNumber: phoneNumber,
    );
  }
}