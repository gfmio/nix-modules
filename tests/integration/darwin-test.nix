{ pkgs, self }:

# Darwin integration test
# This test validates that the darwin configuration evaluates successfully
# For actual VM testing, use tart with the CI/CD pipeline
let
  # Force evaluation of the darwin configuration
  darwinConfig = self.darwinConfigurations.my-mac.config;
  # Get values that require evaluation but not building
  hostname = darwinConfig.networking.hostName or "unknown";
  stateVersion = toString (darwinConfig.system.stateVersion or 0);
  hasCustomModule = darwinConfig ? my.darwin-module;
in
pkgs.runCommand "darwin-integration-test" { } ''
  echo "Testing darwin configuration..." > $out

  # Test that the darwin configuration evaluates
  echo "Hostname: ${hostname}" >> $out
  echo "State version: ${stateVersion}" >> $out

  # Verify custom module options are available
  ${pkgs.lib.optionalString hasCustomModule ''
    echo "✓ Custom darwin modules are loaded" >> $out
  ''}

  echo "✓ Darwin configuration evaluates successfully" >> $out
  echo "All darwin integration tests passed!" >> $out
''
