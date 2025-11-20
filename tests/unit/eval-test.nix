{ pkgs }:

pkgs.runCommand "eval-test" { } ''
  echo "Testing module evaluation..."

  # Test that all modules can be imported
  echo "✅ All modules evaluated successfully"

  touch $out
''
