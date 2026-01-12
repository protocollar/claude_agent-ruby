# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
