import os

filepath = r'c:\Users\Divyansh Khandal\github repos\Astrella\lib\engine_console_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Line 677 and 678 (1-indexed) are 676 and 677 (0-indexed)
# Wait, let's just search for the pattern
target_pattern = "borderSide: BorderSide(color: Color(0xFFF5A623), width: 2),"
for i, line in enumerate(lines):
    if target_pattern in line and i + 2 < len(lines):
        if ")," in lines[i+1] and ")," in lines[i+2] and "const SizedBox(height: 24)," in lines[i+3]:
            # This is the spot
            lines[i+1] = "                                      ),\n"
            lines[i+2] = "                                    ),\n"
            lines.insert(i+3, "                                  ),\n")
            break

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)
