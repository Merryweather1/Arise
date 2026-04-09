import 'dart:io';

void main() async {
  final regExp = RegExp(r'\s+([a-z]+)\s+-\s+(.+?)\s+-\s+([a-zA-Z0-9_\-\\\/\.]+):(\d+):(\d+)\s+-\s+([a-z_]+)');
  
  final targetErrors = [
    'invalid_constant',
    'non_constant_default_value',
    'const_with_non_const',
    'const_initialized_with_non_constant_value',
    'const_eval_throws_exception',
    'non_constant_list_element',
  ];

  while (true) {
    print('Running flutter analyze...');
    final res = await Process.run('flutter.bat', ['analyze']);
    final lines = res.stdout.toString().split('\n');
    final stderrLines = res.stderr.toString().split('\n');
    lines.addAll(stderrLines);

    Map<String, List<Map<String, dynamic>>> fileEdits = {};

    for (var line in lines) {
      final match = regExp.firstMatch(line);
      if (match == null) continue;

      final path = match.group(3)!.trim();
      final lineNum = int.parse(match.group(4)!);
      final colNum = int.parse(match.group(5)!);
      final errorCode = match.group(6)!.trim();
      
      if (targetErrors.contains(errorCode.toLowerCase())) {
          fileEdits.putIfAbsent(path, () => []).add({
            'line': lineNum,
            'col': colNum,
          });
      }
    }

    if (fileEdits.isEmpty) {
      print('No invalid consts found! We are done.');
      break;
    }

    print('Found invalid consts in ${fileEdits.length} files. Removing...');

    int totalRemovedInPass = 0;

    for (var entry in fileEdits.entries) {
      final path = entry.key;
      final edits = entry.value;
      
      // Sort reverse to process bottom-up so offsets don't shift
      edits.sort((a, b) {
        if (a['line'] != b['line']) {
          return b['line'].compareTo(a['line']);
        }
        return b['col'].compareTo(a['col']);
      });

      final file = File(path);
      if (!file.existsSync()) continue;
      
      String content = file.readAsStringSync();
      
      int removedCount = 0;
      
      for (var edit in edits) {
        final targetLineNum = edit['line'];
        final targetColNum = edit['col'];
        
        // Find linear index
        int currentIndex = 0;
        int currentLine = 1;
        while (currentLine < targetLineNum && currentIndex < content.length) {
          int nextNewline = content.indexOf('\n', currentIndex);
          if (nextNewline == -1) break;
          currentIndex = nextNewline + 1;
          currentLine++;
        }
        
        int absoluteIndex = (currentIndex + targetColNum - 1) as int;
        if (absoluteIndex > content.length) absoluteIndex = content.length;
        
        // Scan backwards for 'const' keyword
        int i = absoluteIndex;
        int depth = 0; // Negative means outside, positive means inside a deeper parenthesis
        int foundIdx = -1;
        
        while (i > 4) {
          if (content[i] == ')' || content[i] == '}' || content[i] == ']') {
            depth++;
          } else if (content[i] == '(' || content[i] == '{' || content[i] == '[') {
            depth--;
          }
          
          if (content.substring(i - 5, i) == 'const') {
             // is it a whole word? i.e., followed by space, tab, newline, or parenthesis
             bool nextCharOk = (content[i] == ' ' || content[i] == '\t' || content[i] == '\n' || content[i] == '\r');
             bool prevCharOk = (i - 6 < 0) || !RegExp(r'[a-zA-Z0-9_]').hasMatch(content[i - 6]);
             
             if (nextCharOk && prevCharOk && depth <= 0) {
                 foundIdx = i - 5;
                 break;
             }
          }
          i--;
        }
        
        if (foundIdx != -1) {
           content = '${content.substring(0, foundIdx)}     ${content.substring(foundIdx + 5)}';
           removedCount++;
           totalRemovedInPass++;
        }
      }
      
      if (removedCount > 0) {
         print('  - Removed $removedCount consts in $path');
         file.writeAsStringSync(content);
      }
    }
    
    if (totalRemovedInPass == 0) {
       print('Could not find any more consts to remove! Breaking out to avoid infinite loop.');
       break;
    }
  }
  
  print('Done applying fixes.');
}
