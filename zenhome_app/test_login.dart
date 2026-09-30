void main() {
  String input = "0334861250";
  final phoneRegex = RegExp(r'^(\+84|0)\d{9,10}$');
  bool isPhone = phoneRegex.hasMatch(input) || RegExp(r'^\+\d{10,14}$').hasMatch(input);
  
  String? phoneNumber;
  String emailToLogin = input;

  if (isPhone) {
    phoneNumber = input;
  }

  if (phoneNumber != null) {
    if (phoneNumber.startsWith('0')) phoneNumber = '+84${phoneNumber.substring(1)}';
    else if (!phoneNumber.startsWith('+')) phoneNumber = '+$phoneNumber';
    emailToLogin = '${phoneNumber.replaceAll('+', '')}@zenhome.local';
  }

  print("isPhone: $isPhone");
  print("phoneNumber: $phoneNumber");
  print("emailToLogin: $emailToLogin");
}
