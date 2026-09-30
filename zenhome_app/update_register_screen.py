import re

with open("lib/screens/auth/register_screen.dart", "r", encoding="utf-8") as f:
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
        Text(context.tr('register_title') ?? 'Tạo Tài Khoản', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 10),
        Text(context.tr('register_subtitle') ?? 'Bắt đầu trải nghiệm nhà thông minh', style: TextStyle(color: isWhiteText ? (isDark ? Colors.white70 : Colors.white.withOpacity(0.9)) : color.withOpacity(0.7))),
      ],
    );
  }

"""
    content = content.replace("  @override\n  Widget build(BuildContext context) {", build_header + "  @override\n  Widget build(BuildContext context) {")

scaffold_body_start = content.find("body: Stack(")
scaffold_end = content.rfind("      );")

if scaffold_body_start != -1 and scaffold_end != -1:
    
    textfields_start = content.find("TextField(\n                          controller: _nameController")
    textfields_end = content.find("                  ),\n                ),\n              ),\n            ],\n          ),\n        );\n      }\n    );\n  }\n}")
    
    if textfields_start != -1 and textfields_end != -1:
        fields_code = content[textfields_start:textfields_end].strip()
        # Clean trailing brackets
        fields_code = re.sub(r'\]\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,$', '', fields_code)

        new_body = f"""body: Stack(
            children: [
              // 1. Base Layer (Bottom): Blue text on White background
              SafeArea(
                child: Column(
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
                              const SizedBox(height: 30),
                              
                              {fields_code}
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 2. Wave Layer (Top): Wave background + White text clipped exactly to the wave
              WaveBackground(
                heightPercent: 0.3,
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

with open("lib/screens/auth/register_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

