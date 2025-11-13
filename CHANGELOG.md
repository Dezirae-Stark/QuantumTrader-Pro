# Changelog

All notable changes to QuantumTrader-Pro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Integration tests for broker selection workflow
- F-Droid distribution channel
- iOS version
- Desktop builds (Linux, Windows, macOS)

## [2.1.0] - 2025-01-XX

### Added
- **PR-3: Android Dynamic Catalog Loader**
  - Ed25519 signature verification for broker catalogs
  - Freezed immutable data models
  - Hive local database for catalog caching
  - JSON validation with comprehensive error handling
  - Automatic retry with exponential backoff
  - Memory-efficient streaming for large catalogs

- **PR-4: Broker Selection UI**
  - Complete broker browsing interface
  - Real-time search by name, country, currency, features
  - Platform filtering (MT4/MT5)
  - Broker details screen with full information
  - Broker settings management
  - SharedPreferences persistence
  - Provider state management
  - Copy-to-clipboard for server names
  - Pull-to-refresh functionality

- **PR-5: Secure Release Pipeline**
  - Automated APK signing infrastructure
  - Version management system with bump scripts
  - ProGuard code optimization and obfuscation
  - GitHub Actions release workflow
  - Security scanning (Gitleaks, Trivy)
  - SHA256 checksum generation
  - Ed25519 release signatures

- **Testing Infrastructure**
  - Unit tests for providers and services
  - Widget tests for UI components
  - Mock testing with Mockito
  - CI/CD test automation

### Changed
- **Complete Project Restructure**
  - Migrated from Python/Qt to Flutter/Dart
  - Modern Material Design 3 UI
  - Reactive state management with Provider
  - Modular architecture with clear separation of concerns

- **Build System**
  - Updated to Flutter 3.19.0
  - Gradle 8.x with Kotlin DSL support
  - compileSdk 34 (Android 14)
  - minSdk 26 (Android 8.0)
  - Code generation with build_runner
  - Release builds now ~30% smaller with optimization

### Security
- **Cryptographic Verification**
  - Ed25519 signatures for broker catalog authenticity
  - SHA256 checksums for APK integrity
  - Secure keystore management (never committed)
  - Secret scanning on every commit
  - Vulnerability scanning weekly

- **Release Security**
  - APK signing with RSA 4096-bit keys
  - ProGuard obfuscation in release builds
  - Debug symbols stripped
  - Logging removed in production
  - GitHub Secrets for CI/CD credentials

### Fixed
- Build configuration issues from Qt/Python legacy code
- Android permissions and manifest configuration
- Gradle sync errors with modern Flutter
- Code generation conflicts

### Documentation
- Comprehensive PR implementation plans
  - PR-3-PLAN.md: Catalog loader technical spec
  - PR-4-PLAN.md: UI implementation guide
  - PR-5-PLAN.md: Release pipeline architecture
- Release process documentation
- Keystore setup guide
- Security best practices

### Technical Details
**Dependencies:**
- Flutter SDK 3.19.0
- Dart SDK 3.3.0
- provider: ^6.0.0 (state management)
- shared_preferences: ^2.2.0 (persistence)
- freezed: ^2.4.0 (immutable models)
- hive: ^2.2.0 (local database)
- pointycastle: ^3.7.0 (cryptography)

**CI/CD:**
- GitHub Actions workflows
- Automated code generation
- Security scanning integration
- Release automation

**Testing:**
- flutter_test framework
- mockito: ^5.4.0
- build_runner for code generation
- 50+ test cases (pending code generation)

## [2.0.0] - 2024-XX-XX

### Changed
- Complete platform migration from Python/Qt to Flutter
- New brand identity and app structure

### Removed
- Legacy Python codebase
- Qt dependencies
- Old MetaTrader bridge implementation

## [1.x.x] - Historical

Previous versions were Python/Qt based. See git history for details.

---

## Release Types

- **Major (X.0.0)**: Breaking changes, incompatible API updates
- **Minor (x.X.0)**: New features, backwards-compatible additions
- **Patch (x.x.X)**: Bug fixes, backwards-compatible fixes

## Links

- [Unreleased]: https://github.com/Dezirae-Stark/QuantumTrader-Pro/compare/v2.1.0...HEAD
- [2.1.0]: https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases/tag/v2.1.0
- [2.0.0]: https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases/tag/v2.0.0

## Contributing

When creating a release:
1. Update this CHANGELOG.md with all changes
2. Use `./scripts/bump-version.sh {major|minor|patch}`
3. Commit changes: `git commit -m "chore: Bump version to X.Y.Z"`
4. Create tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. Push: `git push origin main && git push origin vX.Y.Z`

GitHub Actions will automatically build and release.
