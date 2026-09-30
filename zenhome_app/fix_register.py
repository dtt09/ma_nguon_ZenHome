import re

with open("lib/screens/auth/register_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

build_start = content.find("  @override\n  Widget build(BuildContext context) {")
if build_start != -1:
    fields_start = content.find("TextField(\n                          controller: _nameController", build_start)
    # the end is right before the end of the file
    fields_end = content.find("                  ),\n                ),\n              ),\n            ],\n          ),\n        );\n      }\n    );\n  }\n}", build_start)
    
    if fields_start == -1 or fields_end == -1:
        # Maybe the previous python script changed the layout
        fields_start = content.find("TextField(\n", build_start)
        fields_end = content.find("],", fields_start) # Look for the end of children array
        # Let's just find the last ElevatedButton
        elevated_btn_end = content.find("ElevatedButton(\n", fields_start)
        if elevated_btn_end != -1:
            fields_end = content.find("),", content.find("Text(context.tr('btn_register')", elevated_btn_end)) + 2

    if fields_start != -1 and fields_end != -1:
        fields_code = content[fields_start:fields_end].strip()
        fields_code = re.sub(r'\]\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,\s*$', '', fields_code).strip()
        
        # In register_screen there's a SizedBox that wraps the ElevatedButton
        # Make sure we don't truncate the button closing bracket
        # If fields_code is missing a closing bracket for the SizedBox, we append it
        if fields_code.endswith("),") or fields_code.endswith("))") or fields_code.endswith(")"):
            pass
        else:
            fields_code += "\n                          ),"
        
        new_build_method = f"""  @override
  Widget build(BuildContext context) {{
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Builder(
      builder: (context) {{
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
          body: Stack(
            children: [
              // 1. Base Layer
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
              
              // 2. Wave Layer
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
        );
      }}
    );
  }}
}}"""
        content = content[:build_start] + new_build_method
        
        with open("lib/screens/auth/register_screen.dart", "w", encoding="utf-8") as fw:
            fw.write(content)

