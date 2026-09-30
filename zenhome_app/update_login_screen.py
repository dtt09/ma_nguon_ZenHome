import re

with open("lib/screens/auth/login_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Add _buildHeader function if not exists
if "_buildHeader" not in content:
    build_header = """
  Widget _buildHeader(BuildContext context, bool isWhiteText) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isWhiteText ? Colors.white : (isDark ? const Color(0xFF6C8DF0) : const Color(0xFF2A3A7C));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('public/zenhome_logo_transparent.png', width: 75, height: 75, fit: BoxFit.contain, color: color),
        const SizedBox(height: 20),
        Text(
          _isEmailChecked ? (context.tr('welcome_back') ?? 'Chào mừng trở lại') : (context.tr('login') ?? 'Đăng Nhập'), 
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: 1.2, color: color)
        ),
        const SizedBox(height: 10),
        Text(
          _isEmailChecked ? _emailController.text : (context.tr('login_subtitle') ?? 'Đồng bộ nhịp sống, kết nối tương lai.'), 
          style: TextStyle(color: isWhiteText ? (isDark ? Colors.white70 : Colors.white.withOpacity(0.9)) : color.withOpacity(0.7), fontStyle: FontStyle.italic)
        ),
      ],
    );
  }

"""
    content = content.replace("  @override\n  Widget build(BuildContext context) {", build_header + "  @override\n  Widget build(BuildContext context) {")

# Find the start of the Stack inside the Scaffold
scaffold_body_start = content.find("body: Stack(")
scaffold_end = content.rfind("      );")

if scaffold_body_start != -1 and scaffold_end != -1:
    original_stack = content[scaffold_body_start:scaffold_end+8]
    
    # We need to extract the fields from the middle of SingleChildScrollView
    # From "if (!_isEmailChecked)" down to "Row(mainAxisAlignment: MainAxisAlignment.center"
    
    textfields_start = content.find("if (!_isEmailChecked)", scaffold_body_start)
    textfields_end = content.find("                  Positioned(", scaffold_body_start)
    
    if textfields_start != -1 and textfields_end != -1:
        fields_code = content[textfields_start:textfields_end].strip()
        # Remove the closing brackets for the Column and SingleChildScrollView
        # It usually ends with `]` and `),`, let's just use regex to clean it
        fields_code = re.sub(r'\]\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,$', '', fields_code)
        
        language_btn_start = content.find("Positioned(\n                  top: 20,", scaffold_body_start)
        language_btn_end = content.find("              ),\n            ),\n          ],\n        ),", scaffold_body_start)
        
        if language_btn_start != -1 and language_btn_end != -1:
            lang_btn_code = content[language_btn_start:language_btn_end].strip()
        else:
            lang_btn_code = ""

        new_body = f"""body: Stack(
            children: [
              // 1. Base Layer (Bottom): Blue text on White background
              SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 40),
                        _buildHeader(context, false), // Base Header (Blue)
                        
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20),
                                  
                                  {fields_code}
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    {lang_btn_code}
                  ],
                ),
              ),
              
              // 2. Wave Layer (Top): Wave background + White text clipped exactly to the wave
              WaveBackground(
                heightPercent: 0.4,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(context, true), // Top Header (White)
                    ],
                  ),
                ),
              ),
            ],
          ),
        );"""
        
        content = content[:scaffold_body_start] + new_body + content[scaffold_end+8:]

with open("lib/screens/auth/login_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

