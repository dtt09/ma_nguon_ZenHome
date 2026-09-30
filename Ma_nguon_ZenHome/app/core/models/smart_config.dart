class DeviceConfig {
  String id;
  int pin;
  String room;
  String name;
  String icon;

  DeviceConfig({
    required this.id,
    required this.pin,
    required this.room,
    required this.name,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pin': pin,
        'room': room,
        'name': name,
        'icon': icon,
      };

  factory DeviceConfig.fromJson(Map<String, dynamic> json) => DeviceConfig(
        id: json['id'],
        pin: json['pin'],
        room: json['room'],
        name: json['name'],
        icon: json['icon'],
      );
}

class SmartConfig {
  String userId;
  String macAddress;
  String mqttServer; 
  String? mqttUser;
  String? mqttPass;
  String adminPass; 
  List<DeviceConfig> devices;
  String role; 
  String homeName;
  String? ownerEmail;
  bool canEditAutomation;

  SmartConfig({
    required this.userId,
    required this.macAddress,
    this.mqttServer = 'broker.emqx.io', 
    this.mqttUser,
    this.mqttPass,
    this.adminPass = 'admin', 
    required this.devices,
    this.role = 'owner',
    this.homeName = 'My Home',
    this.ownerEmail,
    this.canEditAutomation = false,
  });

  String get mqttPrefix => '$userId/$macAddress';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'macAddress': macAddress,
        'mqttServer': mqttServer, 
        'mqttUser': mqttUser,
        'mqttPass': mqttPass,
        'adminPass': adminPass, 
        'role': role,
        'homeName': homeName,
        'ownerEmail': ownerEmail,
        'canEditAutomation': canEditAutomation,
        'devices': devices.map((e) => e.toJson()).toList(),
      };

  factory SmartConfig.fromJson(Map<String, dynamic> json) => SmartConfig(
        userId: json['userId'] ?? 'guest',
        macAddress: json['macAddress'] ?? 'unknown_mac',
        mqttServer: json['mqttServer'] ?? 'broker.emqx.io', 
        mqttUser: json['mqttUser'],
        mqttPass: json['mqttPass'],
        adminPass: json['adminPass'] ?? 'admin', 
        role: json['role'] ?? 'owner',
        homeName: json['homeName'] ?? 'My Home',
        ownerEmail: json['ownerEmail'],
        devices: json['devices'] != null
            ? (json['devices'] as List).map((e) => DeviceConfig.fromJson(e)).cast<DeviceConfig>().toList()
            : [],
        canEditAutomation: json['canEditAutomation'] ?? false,
      );
}