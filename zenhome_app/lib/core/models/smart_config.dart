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
  List<String>? allowedDevices;
  bool isSubHome;
  String homeIcon;
  String homeType;
  String homeColor;
  List<String> homeRules;

  SmartConfig({
    required this.userId,
    required this.macAddress,
    this.mqttServer = 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud', 
    this.mqttUser = 'DTC_ZenHome',
    this.mqttPass = 'DTC_ZenHome2103',
    this.adminPass = 'admin', 
    required this.devices,
    this.role = 'owner',
    this.homeName = 'My Home',
    this.ownerEmail,
    this.canEditAutomation = false,
    this.allowedDevices,
    this.isSubHome = false,
    this.homeIcon = 'home',
    this.homeType = 'townhouse',
    this.homeColor = '#0F766E',
    this.homeRules = const [],
  });

  String get mqttPrefix => '$userId/$macAddress';
  bool get isHubLinked => macAddress.isNotEmpty && macAddress != 'unknown_mac' && macAddress != 'unknown';

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
        'allowedDevices': allowedDevices,
        'isSubHome': isSubHome,
        'homeIcon': homeIcon,
        'homeType': homeType,
        'homeColor': homeColor,
        'homeRules': homeRules,
        'devices': devices.map((e) => e.toJson()).toList(),
      };

  factory SmartConfig.fromJson(Map<String, dynamic> json) {
    final rawMac = json['macAddress']?.toString() ?? '';
    final cleanMac = (rawMac == 'unknown_mac' || rawMac == 'unknown') ? '' : rawMac;
    return SmartConfig(
        userId: json['userId'] ?? 'guest',
        macAddress: cleanMac,
        mqttServer: (json['mqttServer'] != null && json['mqttServer'].toString().isNotEmpty && json['mqttServer'] != 'broker.emqx.io')
            ? json['mqttServer']
            : 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud', 
        mqttUser: (json['mqttUser'] != null && json['mqttUser'].toString().isNotEmpty && !json['mqttUser'].toString().startsWith('user_'))
            ? json['mqttUser']
            : 'DTC_ZenHome',
        mqttPass: (json['mqttPass'] != null && json['mqttPass'].toString().isNotEmpty)
            ? json['mqttPass']
            : 'DTC_ZenHome2103',
        adminPass: json['adminPass'] ?? 'admin', 
        role: json['role'] ?? 'owner',
        homeName: json['homeName'] ?? 'My Home',
        ownerEmail: json['ownerEmail'],
        devices: json['devices'] != null
            ? (json['devices'] as List).map((e) => DeviceConfig.fromJson(e)).cast<DeviceConfig>().toList()
            : [],
        canEditAutomation: json['canEditAutomation'] ?? false,
        allowedDevices: json['allowedDevices'] != null
            ? List<String>.from(json['allowedDevices'])
            : null,
        isSubHome: json['isSubHome'] ?? false,
        homeIcon: json['homeIcon'] ?? 'home',
        homeType: json['homeType'] ?? 'townhouse',
        homeColor: json['homeColor'] ?? '#0F766E',
        homeRules: json['homeRules'] != null ? List<String>.from(json['homeRules']) : [],
      );
  }
}