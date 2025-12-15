# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

task default: %i[spec rubocop]

desc "Run all quality checks"
task :quality do
  Rake::Task["rubocop"].invoke
  Rake::Task["spec"].invoke
  puts "\n✅ All quality checks passed!"
end

desc "Generate documentation and open in browser"
task :doc do
  Rake::Task["yard"].invoke
  system "open doc/index.html"
end
