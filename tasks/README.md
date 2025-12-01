# Task Organization

This directory contains all task definitions organized into logical categories and tool-specific namespaces.

## Structure

```
tasks/
├── logical/          # Task categories by purpose
│   ├── bench.yml     # Benchmarking and profiling
│   ├── build.yml     # Build tasks
│   ├── ci.yml        # CI/CD tasks
│   ├── clean.yml     # Cleanup tasks
│   ├── deadcode.yml  # Dead code detection
│   ├── deploy.yml    # Deployment tasks
│   ├── dev.yml       # Development tasks
│   ├── docs.yml      # Documentation generation
│   ├── format.yml    # Code formatting
│   ├── health.yml    # Health checks
│   ├── lint.yml      # Linting tasks
│   ├── setup.yml     # Environment setup
│   └── test.yml      # Testing tasks
├── tools/            # Tool-specific namespaces
│   ├── deadnix.yml   # deadnix linter
│   ├── direnv.yml    # direnv setup
│   ├── home-manager.yml # home-manager operations
│   ├── nix.yml       # Nix commands
│   ├── statix.yml    # statix linter
│   └── tart.yml      # tart VM manager
├── logical.yml       # Aggregates logical tasks
└── tools.yml         # Aggregates tool tasks
```

## Usage

All tasks are flattened in the main Taskfile, so you can call them directly:

```bash
# Logical tasks
task build              # Build all configurations
task test               # Run all tests
task ci                 # Run CI checks
task health             # Check development environment
task deploy:nixos       # Deploy NixOS configuration
task bench:eval         # Benchmark evaluation performance

# Tool-specific tasks
task nix:build:nixos    # Build NixOS with nix
task nix:test:unit      # Run unit tests
task home-manager:build # Build home-manager configs
```

## Watch Mode

Many tasks support watch mode with the `--watch` flag:

```bash
# Auto-run CI checks when files change
task --watch ci:quick

# Auto-format on file changes
task --watch format

# Auto-run tests when files change
task --watch test
```

Tasks with `sources` defined will automatically re-run when those files change.

## Key Features

### Platform-Aware

Tasks automatically detect the platform and skip incompatible operations:

```bash
task deploy:darwin      # Only runs on macOS
task deploy:nixos       # Only runs on Linux
```

### Wildcards

Build and manage configurations by name:

```bash
task nix:build:nixos:my-nixos-box    # Specific config
task nix:build:nixos:my-server       # Another config
task nix:build:darwin:*               # Any darwin config
```

### Health Checks

Verify your development environment:

```bash
task health              # Full health check
task health:nix          # Check Nix installation
task health:tools        # Check development tools
task health:platform     # Check platform-specific tools
```

### Deployment

Safe deployment with dry-run and test options:

```bash
task deploy:dry-run:nixos    # See what would change
task deploy:test:nixos       # Build and activate without boot
task deploy:nixos            # Full deployment
```

### VM Testing with Tart

Run integration tests in ephemeral VMs (macOS host only):

```bash
# macOS VM setup (pulls from Cirrus Labs registry)
task tart:pull:macos        # Pull clean macOS base image
task tart:base:macos        # Create test base with nix pre-installed

# NixOS VM setup (must be created locally from ISO)
task tart:create:nixos      # Create clean NixOS from ISO (interactive)
task tart:create:nixos:auto # Create clean NixOS from ISO (automated)
task tart:base:nixos        # Create test base

# Run tests
task tart:test:darwin       # Run darwin tests in VM
task tart:test:nixos        # Run NixOS tests in VM
task tart:test              # Run both

# Utilities
task tart:list              # List all VM images
task tart:info              # Show VM testing workflow info
task tart:clean:test        # Clean up leftover test VMs
```

The VM testing workflow:

1. **macOS**: Pull clean base from `ghcr.io/cirruslabs/macos-tahoe-base`
2. **NixOS**: Create clean base from ISO (no registry image available)
3. Run setup scripts to create test base images with nix/tools pre-installed
4. For each test run, clone the base → run tests → destroy clone
5. Base images are reused across test runs for speed

## Adding New Tasks

### Logical Task

Add to `tasks/logical/<category>.yml`:

```yaml
tasks:
  my-task:
    desc: Description of my task
    sources:
      - '**/*.nix'  # Watch these files
    cmds:
      - echo "Running task..."
      - task: nix:some-command
```

### Tool-Specific Task

Add to `tasks/tools/<tool>.yml`:

```yaml
tasks:
  tool:command:
    desc: Run tool command
    sources:
      - '**/*.nix'
    cmds:
      - tool-binary --flag
```

## Best Practices

1. **Use `sources`**: Add `sources` to tasks that should support watch mode
2. **Platform gates**: Use `platforms: [darwin]` or `platforms: [linux]` for platform-specific tasks
3. **Descriptive names**: Use `:` to namespace tasks (e.g., `nix:build:darwin`)
4. **Aliases**: Add common shortcuts with `aliases: [short-name]`
5. **Dependencies**: Use `deps: [task1, task2]` for tasks that must run first
6. **Silent tasks**: Add `silent: true` for info/help tasks
