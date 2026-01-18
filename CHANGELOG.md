# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.3] - 2026-01-18

### Changed
- Updated release workflow to use trusted publisher

## [0.4.2] - 2026-01-18

### Fixed
- Release script now uses `bundle install` (Bundler 4.x compatibility)

### Changed
- Release script prompts for RubyGems OTP upfront
- Release script creates GitHub releases automatically

## [0.4.1] - 2026-01-18

### Changed
- Simplified release script to match Kamal's approach

## [0.4.0] - 2026-01-18

### Added
- `TaskNotificationMessage` for background task completion notifications
- `Setup` hook event with `SetupInput` for init/maintenance triggers
- `skills` and `max_turns` fields in `AgentDefinition` (TypeScript SDK v0.2.12 parity)
- `init`, `init_only`, `maintenance` options for running Setup hooks
- `ClaudeAgent.run_setup` convenience method for CI/CD pipelines
- Hook-specific output fields documentation (`additionalContext`, `permissionDecision`, `updatedMCPToolOutput`, etc.)
- Document `settings` option accepts JSON strings (for plansDirectory, etc.)

## [0.3.0] - 2026-01-16

### Added
- `agent` option for specifying main thread agent name (TypeScript SDK v0.2.9 parity)
- `model` field in `SessionStartInput` hook input

## [0.2.0] - 2026-01-11

### Added
- V2 Session API for multi-turn conversations (`unstable_v2_create_session`, `unstable_v2_resume_session`, `unstable_v2_prompt`)
- `Session` class for stateful conversation management
- `SessionOptions` data type for V2 API configuration

### Fixed
- `Options#initialize` now correctly handles nil values without overriding defaults

## [0.1.0] - 2026-01-10

### Added
- MVP implementation of the Claude Agent SDK for Ruby
