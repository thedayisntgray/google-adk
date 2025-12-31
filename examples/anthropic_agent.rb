#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/google/adk"

# Example of using Google ADK with Anthropic's Claude models
#
# This example shows how to create an LLM agent that uses Claude instead of Gemini.
# Make sure to set your ANTHROPIC_API_KEY environment variable before running.

# Create an agent using Claude
agent = Google::ADK::LlmAgent.new(
  name: "Claude Assistant",
  model: "claude-3-5-sonnet-20241022", # This will automatically use AnthropicClient
  instructions: "You are a helpful AI assistant powered by Claude. Be concise and informative.",
  description: "An AI assistant using Anthropic's Claude model"
)

# Alternative: Force Anthropic client with environment variable
# ENV["USE_ANTHROPIC"] = "true"
# agent = Google::ADK::LlmAgent.new(
#   name: "Assistant",
#   model: "any-model-name", # Will use AnthropicClient due to USE_ANTHROPIC env var
#   instructions: "You are a helpful assistant."
# )

# Create a runner
runner = Google::ADK::Runner.new(agent: agent)

# Example conversation
puts "Claude Assistant Example"
puts "=" * 50
puts

# Simple query
response = runner.run("What are the main differences between Ruby and Python?")
puts "Q: What are the main differences between Ruby and Python?"
puts "A: #{response}"
puts

# You can also use SimpleLlmAgent with Claude
simple_agent = Google::ADK::SimpleLlmAgent.new(
  model: "claude-3-5-sonnet-20241022",
  name: "Simple Claude",
  instructions: "Provide brief, clear answers."
)

puts "Simple Claude Agent Example"
puts "=" * 50
puts

response = simple_agent.call("Explain recursion in one sentence.")
puts "Q: Explain recursion in one sentence."
puts "A: #{response}"
puts

# Tool usage example with Claude
if ARGV[0] == "--with-tools"
  # Define a simple tool
  weather_tool = Google::ADK::FunctionTool.new(
    name: "get_weather",
    description: "Get current weather for a location",
    parameters: {
      type: "object",
      properties: {
        location: { type: "string", description: "City name" }
      },
      required: ["location"]
    }
  ) do |location:|
    # Mock weather data
    { temperature: "72°F", condition: "Sunny", location: location }
  end

  # Create agent with tools
  agent_with_tools = Google::ADK::LlmAgent.new(
    name: "Claude Weather Bot",
    model: "claude-3-5-sonnet-20241022",
    instructions: "You are a weather assistant. Use the get_weather tool when asked about weather.",
    tools: [weather_tool]
  )

  runner_with_tools = Google::ADK::Runner.new(agent: agent_with_tools)
  
  puts "Claude with Tools Example"
  puts "=" * 50
  puts
  
  response = runner_with_tools.run("What's the weather like in San Francisco?")
  puts "Q: What's the weather like in San Francisco?"
  puts "A: #{response}"
end