import 'dart:io';

void main() {
  final file = File('lib/screens/auth/otp_verification_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst('final _pinController = TextEditingController();', 'final _pinController = TextEditingController();\n  final _pinFocusNode = FocusNode();');
  
  content = content.replaceFirst('  @override\n  void initState() {', '  @override\n  void initState() {\n    super.initState();\n    _pinFocusNode.addListener(() { if (mounted) setState(() {}); });');
  
  content = content.replaceFirst('    _pinController.dispose();', '    _pinFocusNode.dispose();\n    _pinController.dispose();');
  
  // Replace Pinput
  final pinputRegex = RegExp(r'Pinput\([\s\S]*?onCompleted:.*?,\n\s*\),');
  final pinputMatch = pinputRegex.firstMatch(content);
  if (pinputMatch != null) {
    String pinputStr = pinputMatch.group(0)!;
    pinputStr = pinputStr.replaceFirst('controller: _pinController,', 'controller: _pinController,\n                      focusNode: isTopLayer ? null : _pinFocusNode,');
    content = content.replaceFirst(pinputMatch.group(0)!, 'isTopLayer ? IgnorePointer(child: $pinputStr) : $pinputStr');
  }
  
  // Fix borders
  content = content.replaceFirst('border: Border.all(color: color.withOpacity(0.3)),', 'border: Border.all(color: (isTopLayer && _pinFocusNode.hasFocus) ? color : color.withOpacity(0.3)),');
  
  file.writeAsStringSync(content);
}
