import re

with open("lib/screens/auth/login_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Find the start of the build method
build_start = content.find("  @override\n  Widget build(BuildContext context) {")
if build_start != -1:
    # We will just rewrite the entire build method properly
    # First, let's extract the fields code
    fields_start = content.find("if (!_isEmailChecked)", build_start)
    fields_end = content.find("Positioned(", build_start)
    if fields_start != -1 and fields_end != -1:
        fields_code = content[fields_start:fields_end].strip()
        # Clean up any trailing brackets
        fields_code = re.sub(r'\]\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*$', '', fields_code).strip()
        
        lang_btn_start = content.find("Positioned(", build_start)
        lang_btn_end = content.find("              ),\n            ),\n          ],\n        ),\n      );\n    });\n  }\n}", build_start)
        
        if lang_btn_start != -1 and lang_btn_end != -1:
            lang_btn_code = content[lang_btn_start:lang_btn_end].strip()
            # Clean trailing brackets for lang btn
            lang_btn_code = re.sub(r'\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*$', '', lang_btn_code).strip()
            if lang_btn_code.endswith(')'):
                lang_btn_code += ','
            
            new_build_method = f"""  @override
  Widget build(BuildContext context) {{
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Builder(
      builder: (context) {{ String currentLang = ref.watch(localeNotifierProvider).languageCode;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
          body: Stack(
            children: [
              // 1. Base Layer
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
              
              // 2. Wave Layer
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
        );
      }}
    );
  }}
}}"""
            
            content = content[:build_start] + new_build_method
            
            with open("lib/screens/auth/login_screen.dart", "w", encoding="utf-8") as fw:
                fw.write(content)

