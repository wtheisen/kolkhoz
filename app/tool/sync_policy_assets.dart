import 'dart:io';

void main() {
  final appRoot = Directory.current;
  final repoRoot = appRoot.parent;
  final source = Directory('${repoRoot.path}/policies');
  final destination = Directory('${appRoot.path}/assets/policies');
  const names = [
    'current_best_policy.json',
    'medium_policy.json',
    'hard_policy.json',
  ];

  if (!source.existsSync()) {
    stderr.writeln('Canonical policy directory not found: ${source.path}');
    exitCode = 1;
    return;
  }

  destination.createSync(recursive: true);
  for (final name in names) {
    final input = File('${source.path}/$name');
    if (!input.existsSync()) {
      stderr.writeln('Canonical policy not found: ${input.path}');
      exitCode = 1;
      return;
    }
    input.copySync('${destination.path}/$name');
  }
}
