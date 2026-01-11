# frozen_string_literal: true

require_relative "lib/claude_agent/version"

Gem::Specification.new do |spec|
  spec.name = "claude_agent"
  spec.version = ClaudeAgent::VERSION
  spec.authors = [ "Thomas Carr" ]
  spec.email = [ "9591402+htcarr3@users.noreply.github.com" ]

  spec.summary = "Ruby SDK for building AI agents with Claude Code"
  spec.description = <<~DESC
    ClaudeAgent is a Ruby SDK for building autonomous AI agents that interact with
    Claude Code CLI. It provides both simple one-shot queries and interactive
    bidirectional sessions with support for tool use, hooks, permissions, and
    in-process MCP servers.
  DESC
  spec.homepage = "https://github.com/protocollar/claude_agent-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml vendor/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_dependency "activesupport", ">= 7.0"
end
