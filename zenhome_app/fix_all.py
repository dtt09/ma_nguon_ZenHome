import re

# Fix login_screen.dart
with open("lib/screens/auth/login_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

build_start = content.find("  @override\n  Widget build(BuildContext context) {")
if build_start != -1:
    # Extract fields
    fields_start = content.find("if (!_isEmailChecked)", build_start)
    fields_end = content.find("                                ],\n                              ),\n                            ),\n                          ),\n                        ),\n                      ],\n                    ),\n                    Positioned(", build_start)
    if fields_start != -1 and fields_end != -1:
        fields = content[fields_start:fields_end].strip()
        
        build_method = """  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Builder(
      builder: (context) { String currentLang = ref.watch(localeNotifierProvider).languageCode;
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
"""
        build_method += "                                  " + fields + "\n"
        build_method += """                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: InkWell(
                        onTap: () async {
                          String newLang = currentLang == 'vi' ? 'en' : 'vi';
                          ref.read(localeNotifierProvider.notifier).setLocale(newLang);
                          
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('app_lang', newLang);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language, size: 18, color: isDark ? Colors.white70 : const Color(0xFF2A3A7C)),
                              const SizedBox(width: 6),
                              Text(
                                currentLang == 'vi' ? 'VN' : 'EN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF2A3A7C),
                                ),
                              ),
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
      }
    );
  }
}"""
        content = content[:build_start] + build_method
        with open("lib/screens/auth/login_screen.dart", "w", encoding="utf-8") as f:
            f.write(content)

# Fix register_screen.dart
with open("lib/screens/auth/register_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

build_start = content.find("  @override\n  Widget build(BuildContext context) {")
if build_start != -1:
    fields_start = content.find("TextField(\n                          controller: _nameController", build_start)
    fields_end = content.find("Text(context.tr('btn_register')", build_start)
    
    if fields_start != -1 and fields_end != -1:
        # include up to the end of the button
        fields_end = content.find("),", fields_end) + 2
        fields = content[fields_start:fields_end].strip()
        
        build_method = """  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Builder(
      builder: (context) {
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
"""
        build_method += "                              " + fields + "\n"
        build_method += """                            ],
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
      }
    );
  }
}"""
        content = content[:build_start] + build_method
        with open("lib/screens/auth/register_screen.dart", "w", encoding="utf-8") as f:
            f.write(content)

