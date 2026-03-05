class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String mailAddress;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.mailAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'mailAddress': mailAddress,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    String readString(String key, {String fallback = ''}) {
      final v = json[key];
      if (v == null) return fallback;
      if (v is String) return v;
      return v.toString();
    }

    return EmergencyContact(
      id: readString(
        'id',
        fallback: DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      name: readString('name', fallback: 'Inconnu'),
      phoneNumber: readString('phoneNumber'),
      mailAddress: readString('mailAddress'),
    );
  }

  factory EmergencyContact.create({
    required String name,
    required String phoneNumber,
    required String mailAddress,
  }) {
    return EmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phoneNumber: phoneNumber,
      mailAddress: mailAddress,
    );
  }
}
