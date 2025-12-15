#!/usr/bin/env ruby
# frozen_string_literal: true

require "google-adk"

# Example: Multi-agent system with workflow agents
# This demonstrates how to combine multiple agents using workflow patterns

# Simple agents that simulate different tasks
research_agent = Google::ADK::LlmAgent.new(
  name: "researcher",
  model: "gemini-2.0-flash",
  instructions: "You research topics and gather information"
)

analyzer_agent = Google::ADK::LlmAgent.new(
  name: "analyzer", 
  model: "gemini-2.0-flash",
  instructions: "You analyze data and identify patterns"
)

writer_agent = Google::ADK::LlmAgent.new(
  name: "writer",
  model: "gemini-2.0-flash",
  instructions: "You write clear summaries and reports"
)

# Sequential workflow: Research → Analyze → Write
sequential_workflow = Google::ADK::SequentialAgent.new(
  name: "report_generator",
  description: "Generates reports through research, analysis, and writing",
  agents: [research_agent, analyzer_agent, writer_agent]
)

# Parallel workflow: Multiple perspectives
perspective_agent1 = Google::ADK::LlmAgent.new(
  name: "optimist",
  model: "gemini-2.0-flash",
  instructions: "You provide optimistic perspectives"
)

perspective_agent2 = Google::ADK::LlmAgent.new(
  name: "realist",
  model: "gemini-2.0-flash",
  instructions: "You provide realistic perspectives"
)

parallel_perspectives = Google::ADK::ParallelAgent.new(
  name: "perspective_analyzer",
  description: "Gathers multiple perspectives on a topic",
  agents: [perspective_agent1, perspective_agent2],
  aggregation_strategy: :all
)

# Loop workflow: Iterative refinement
refiner_agent = Google::ADK::LlmAgent.new(
  name: "refiner",
  model: "gemini-2.0-flash",
  instructions: "You refine and improve content iteratively"
)

iterative_refiner = Google::ADK::LoopAgent.new(
  name: "content_refiner",
  description: "Iteratively refines content",
  agent: refiner_agent,
  max_iterations: 3,
  loop_condition: proc { |result, iteration| 
    # Continue if result needs improvement and we haven't hit max
    iteration < 3 && (!result || result.length < 100)
  }
)

# Master coordinator that uses all workflows
master_agent = Google::ADK::LlmAgent.new(
  name: "coordinator",
  model: "gemini-2.0-flash",
  instructions: "You coordinate between different specialized agents",
  tools: [sequential_workflow, parallel_perspectives, iterative_refiner]
)

# Create runner
runner = Google::ADK::InMemoryRunner.new(
  agent: master_agent,
  app_name: "multi_agent_demo"
)

# Example usage
puts "Multi-Agent System Example"
puts "=" * 50

# Run a simple task
events = runner.run(
  user_id: "demo_user",
  message: "Create a brief report about AI agents"
).to_a

# Display results
events.each do |event|
  if event.content
    puts "\n[#{event.author}]: #{event.content}"
  end
end

puts "\n" + "=" * 50
puts "Execution complete!"

# Example of direct workflow usage
puts "\nDirect Sequential Workflow Example:"
puts "-" * 30

sequential_events = sequential_workflow.run_async(
  "What are the benefits of Ruby programming?"
).to_a

sequential_events.each do |event|
  if event.content && event.author == "report_generator"
    puts "[#{event.author}]: #{event.content}"
  end
end