void main() {
  String deviceId = "my_device_123";
  bool isOn = true;
  var state = {"other": false};
  var newState = {...state, deviceId: isOn};
  print(newState);
}
