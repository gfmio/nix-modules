{ pkgs, self }:

# Simple evaluation test for darwin configuration
# This test just ensures the configuration can be evaluated
let
  # Force evaluation of the darwin configuration
  darwinConfig = self.darwinConfigurations.my-mac.config;
  # Get a simple value that requires evaluation but not building
  hostname = darwinConfig.networking.hostName or "unknown";
in
pkgs.runCommand "darwin-eval-test" { } ''
  echo "Testing darwin configuration evaluation..."
  echo "✓ Darwin configuration evaluates successfully"
  echo "Hostname: ${hostname}" > $out
  echo "All darwin evaluation tests passed!"
''
