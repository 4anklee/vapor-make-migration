# CI/CD Documentation

This document describes the continuous integration and deployment setup for vapor-make-migration.

## GitHub Actions Workflows

### 1. Tests Workflow (`test.yml`)

**Triggers:**
- Push to `main` or `dev` branches
- Pull requests to `main` or `dev` branches

**Jobs:**

#### Test Job
- **Platforms**: Ubuntu Latest, macOS Latest
- **Swift Version**: 6.0
- **Steps**:
  1. Checkout code
  2. Set up Swift 6.0
  3. Cache Swift packages for faster builds
  4. Build project
  5. Run tests
  6. Build release (macOS only)

#### Lint Job
- **Platform**: macOS Latest
- **Steps**:
  1. Checkout code
  2. Run SwiftLint (continues on error)

### 2. Code Quality Workflow (`code-quality.yml`)

**Triggers:**
- Pull requests to `main` or `dev` branches

**Jobs:**

#### Format Check
- Validates code formatting standards
- Non-blocking (continues on error)

#### Documentation Check
- Ensures documentation can be generated
- Non-blocking (continues on error)

#### Security Audit
- Placeholder for security scanning
- Can be extended with dependency auditing tools

### 3. Release Workflow (`release.yml`)

**Triggers:**
- Tags matching `v*.*.*` pattern (e.g., v1.0.0)

**Jobs:**

#### Build and Release
- **Platforms**:
  - macOS x86_64 (Intel)
  - macOS ARM64 (Apple Silicon)
  - Linux x86_64

- **Outputs**:
  - Binary artifacts for each platform
  - Uploaded as GitHub Actions artifacts

#### Create Release
- Downloads all platform binaries
- Creates GitHub Release with:
  - Release notes
  - Installation instructions for each platform
  - Downloadable binaries

## Pull Request Process

### Automatic Checks

When you open a PR, the following checks run automatically:

1. ✅ **Build Check** - Ensures code compiles
2. ✅ **Test Suite** - All 22 tests must pass
3. ✅ **Platform Compatibility** - Tests on macOS and Linux
4. ⚠️ **Code Quality** - Formatting and documentation checks (non-blocking)

### Status Badges

The README includes badges showing:
- Test status
- Swift version
- Supported platforms
- License

## Local Development

### Running CI Checks Locally

Before pushing, run these locally:

```bash
# Build
swift build

# Run tests
swift test

# Build release
swift build -c release

# Check for warnings
swift build --verbose
```

### Pre-commit Checks

Recommended pre-commit checks:

```bash
#!/bin/bash
# Save as .git/hooks/pre-commit

echo "Running tests..."
swift test || exit 1

echo "Building release..."
swift build -c release || exit 1

echo "All checks passed!"
```

## Release Process

### Creating a Release

1. **Update Version**
   - Update version in `Package.swift`
   - Update `CHANGELOG.md`

2. **Create Tag**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

3. **Automatic Build**
   - GitHub Actions builds binaries for all platforms
   - Creates GitHub Release automatically
   - Uploads binaries as release assets

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (v2.0.0): Breaking changes
- **MINOR** (v1.1.0): New features (backward compatible)
- **PATCH** (v1.0.1): Bug fixes

## Environment Secrets

No secrets are currently required for CI/CD. The workflows use:
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

## Caching Strategy

Swift packages are cached using:
- **Cache Key**: Based on `Package.resolved` hash
- **Restore Keys**: Falls back to most recent cache for the OS
- **Benefits**: Faster builds, reduced network usage

## Monitoring

### Build Status

Check build status at:
- https://github.com/yourusername/vapor-make-migration/actions

### Notifications

GitHub sends notifications for:
- Failed CI checks
- Successful releases
- PR reviews

## Troubleshooting

### Common CI Issues

#### Tests Fail on Linux but Pass on macOS
- Check for platform-specific code
- Verify file paths use correct separators
- Test locally with Docker:
  ```bash
  docker run --rm -v "$PWD:/workspace" swift:6.0 bash -c "cd /workspace && swift test"
  ```

#### Cache Issues
- Clear cache by incrementing cache version in workflow
- Or manually delete caches in GitHub Actions settings

#### Build Timeouts
- Default timeout: 60 minutes
- Can be extended with `timeout-minutes:` in workflow

## Future Improvements

Potential CI/CD enhancements:

- [ ] Code coverage reporting
- [ ] Performance benchmarks
- [ ] Automated changelog generation
- [ ] Docker image publishing
- [ ] Homebrew formula updates
- [ ] Documentation deployment
- [ ] Nightly builds from `dev` branch

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Swift on GitHub Actions](https://github.com/swift-actions)
- [Semantic Versioning](https://semver.org/)
