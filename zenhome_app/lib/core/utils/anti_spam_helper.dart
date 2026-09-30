import 'dart:async';

class AntiSpamHelper {
  static final Map<String, bool> _locked = {};
  
  /// Gọi hàm `action` nếu hành động với `key` chưa bị khóa. 
  /// Nếu gọi liên tiếp trong khoảng thời gian `cooldown`, các lệnh sau sẽ bị bỏ qua (Chống Spam).
  static void throttle(String key, Duration cooldown, Function action) {
    if (_locked[key] == true) return;
    
    _locked[key] = true;
    action();
    
    Timer(cooldown, () {
      _locked[key] = false;
    });
  }
}
