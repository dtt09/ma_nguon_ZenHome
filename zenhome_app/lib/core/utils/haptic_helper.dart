import 'package:flutter/services.dart';

class HapticHelper {
  static void heavy() {
    HapticFeedback.heavyImpact();
  }
  static void medium() {
    HapticFeedback.mediumImpact();
  }
  static void light() {
    HapticFeedback.lightImpact();
  }
  static void errorVibrate() {
    HapticFeedback.vibrate();
  }
  static void warning() {
    HapticFeedback.mediumImpact();
  }
}