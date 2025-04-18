import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

void main() {
  final files =
      Directory(
        '${Directory.current.path}/lib/l10n',
      ).listSync().whereType<File>();
  final mirrorFile = File('${Directory.current.path}/lib/l10n/app_en.arb');

  final mirrorContent = mirrorFile.readAsStringSync();
  final mirrorMap = Map<String, dynamic>.from(json.decode(mirrorContent));

  for (final file in files) {
    if (file.path == mirrorFile.path) continue;

    final content = file.readAsStringSync();
    final contentMap = Map<String, dynamic>.from(json.decode(content));
    contentMap.removeWhere(
      (key, value) => key.replaceAll('"', '').startsWith('@'),
    );

    final newContentMap = <String, dynamic>{
      for (final key in mirrorMap.keys) key: contentMap[key] ?? mirrorMap[key],
    };
    newContentMap['@@locale'] =
        path.basenameWithoutExtension(file.path).split('_').last;

    final newContent = const JsonEncoder.withIndent(
      '  ',
    ).convert(newContentMap);
    file.writeAsString(newContent);
  }

  Process.run('flutter', ['gen-l10n'], runInShell: true);
}
