#!/usr/bin/env ruby
# frozen_string_literal: true

require "google-adk"

# Example of creating a basic agent
agent = Google::ADK::BaseAgent.new(
  name: "example_agent",
  description: "An example agent to demonstrate the base functionality"
)

puts "Created agent: #{agent.name}"
puts "Description: #{agent.description}"

# Example with sub-agents
sub_agent1 = Google::ADK::BaseAgent.new(
  name: "research_agent",
  description: "Handles research tasks"
)

sub_agent2 = Google::ADK::BaseAgent.new(
  name: "analysis_agent", 
  description: "Handles analysis tasks"
)

parent_agent = Google::ADK::BaseAgent.new(
  name: "coordinator",
  description: "Coordinates between research and analysis",
  sub_agents: [sub_agent1, sub_agent2]
)

puts "\nParent agent: #{parent_agent.name}"
puts "Sub-agents:"
parent_agent.sub_agents.each do |sub|
  puts "  - #{sub.name}: #{sub.description}"
end

# Example of finding agents in hierarchy
found = parent_agent.find_agent("research_agent")
puts "\nFound agent '#{found.name}' in hierarchy" if found

# Example with callbacks
before_callback = proc { |agent, message| puts "Before processing: #{message}" }
after_callback = proc { |agent, result| puts "After processing: #{result}" }

agent_with_callbacks = Google::ADK::BaseAgent.new(
  name: "callback_agent",
  description: "Agent with lifecycle callbacks",
  before_agent_callback: before_callback,
  after_agent_callback: after_callback
)

# Note: BaseAgent#run_async is abstract and must be implemented in subclasses
begin
  agent.run_async("Hello")
rescue NotImplementedError => e
  puts "\nExpected error: #{e.message}"
end