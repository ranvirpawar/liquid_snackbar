import 'dart:io';

void main() {
  var lines = 0;
  var covered = 0;
  var source = false;
  for (final line in File('coverage/lcov.info').readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      source = line.replaceAll(r'\', '/').contains('lib/src/');
    } else if (source && line.startsWith('DA:')) {
      lines++;
      if (int.parse(line.split(',')[1]) > 0) covered++;
    }
  }
  final percent = lines == 0 ? 0 : covered * 100 / lines;
  stdout.writeln(
    'lib/src line coverage: $covered/$lines (${percent.toStringAsFixed(2)}%)',
  );
  if (percent <= 85) exitCode = 1;
}
