import 'json_parse.dart';

class ConductorBus {
  final int conductorId;
  final bool isActive;
  final DateTime assignedAt;
  final DateTime updatedAt;

  final int busId;
  final String licensePlateNo;
  final String routeNo;
  final int capacity;
  final String model;
  final String serviceType;

  final int operatorId;
  final String companyName;
  final String companyEmail;
  final String companyPhone;
  final bool companyVerified;

  ConductorBus({
    required this.conductorId,
    required this.isActive,
    required this.assignedAt,
    required this.updatedAt,
    required this.busId,
    required this.licensePlateNo,
    required this.routeNo,
    required this.capacity,
    required this.model,
    required this.serviceType,
    required this.operatorId,
    required this.companyName,
    required this.companyEmail,
    required this.companyPhone,
    required this.companyVerified,
  });

  factory ConductorBus.fromJson(Map<String, dynamic> j) {
    return ConductorBus(
      conductorId: jInt(j["conductor_id"]),
      isActive: jBool(j["is_active"]),
      assignedAt: DateTime.parse(jStr(j["assigned_at"])),
      updatedAt: DateTime.parse(jStr(j["updated_at"])),
      busId: jInt(j["bus_id"]),
      licensePlateNo: jStr(j["license_plate_no"]),
      routeNo: jStr(j["route_no"]),
      capacity: jInt(j["capacity"]),
      model: jStr(j["model"]),
      serviceType: jStr(j["service_type"]),
      operatorId: jInt(j["operator_id"]),
      companyName: jStr(j["company_name"]),
      companyEmail: jStr(j["company_email"]),
      companyPhone: jStr(j["company_phone"]),
      companyVerified: jBool(j["company_verified"]),
    );
  }
}
