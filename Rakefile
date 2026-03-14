# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

# Unit tests only (default, fast, no CLI required)
Minitest::TestTask.create(:test) do |t|
  t.test_globs = [ "test/claude_agent/**/test_*.rb" ]
  t.warning = false
end

# Internal task for running all tests
Minitest::TestTask.create(:_all) do |t|
  t.test_globs = [ "test/**/test_*.rb" ]
  t.warning = false
end

# All tests - wrapper that sets INTEGRATION=true
desc "Run all tests including integration (requires Claude CLI)"
task :test_all do
  ENV["INTEGRATION"] = "true"
  Rake::Task[:_all].invoke
end

# Internal task for running integration tests
Minitest::TestTask.create(:_integration) do |t|
  t.test_globs = [ "test/integration/**/test_*.rb" ]
  t.warning = false
end

# Integration tests - wrapper that sets INTEGRATION=true
desc "Run integration tests (requires Claude CLI)"
task :test_integration do
  ENV["INTEGRATION"] = "true"
  Rake::Task[:_integration].invoke
end

# Internal task for running smoke tests
Minitest::TestTask.create(:_smoke) do |t|
  t.test_globs = [ "test/smoke/**/test_*.rb" ]
  t.warning = false
end

# Smoke tests - wrapper that sets INTEGRATION + SMOKE + Ollama defaults
desc "Run smoke tests against local LLM (e.g. Ollama)"
task :test_smoke do
  ENV["INTEGRATION"] = "true"
  ENV["SMOKE"] = "true"
  ENV["ANTHROPIC_BASE_URL"] ||= "http://localhost:11434"
  ENV["ANTHROPIC_API_KEY"] ||= "ollama"
  ENV["ANTHROPIC_AUTH_TOKEN"] ||= "ollama"
  Rake::Task[:_smoke].invoke
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

# RBS validation tasks
namespace :rbs do
  desc "Validate RBS signatures (syntax + type resolution)"
  task :validate do
    sh "bundle exec rbs -r logger -I sig validate"
  end

  desc "Parse RBS files (syntax check only, faster)"
  task :parse do
    sh "bundle exec rbs parse sig/**/*.rbs"
  end

  desc "Generate RBS prototype from lib/ (outputs to stdout)"
  task :prototype do
    sh "bundle exec rbs prototype rb lib/**/*.rb"
  end
end

desc "Validate RBS signatures"
task rbs: "rbs:validate"

task default: %i[test rbs rubocop]
