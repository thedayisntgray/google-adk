#!/usr/bin/env ruby
# frozen_string_literal: true

require "google-adk"

# Example: Using tools with agents
# This demonstrates how to create and use custom tools

# Define custom function tools
calculator_tool = Google::ADK::FunctionTool.new(
  name: "calculator",
  description: "Performs basic arithmetic operations",
  callable: proc { |operation:, a:, b:|
    case operation
    when "add" then a + b
    when "subtract" then a - b
    when "multiply" then a * b
    when "divide" then b.zero? ? "Error: Division by zero" : a.to_f / b
    else
      "Unknown operation: #{operation}"
    end
  },
  parameters_schema: {
    "type" => "object",
    "properties" => {
      "operation" => {
        "type" => "string",
        "enum" => ["add", "subtract", "multiply", "divide"],
        "description" => "The arithmetic operation to perform"
      },
      "a" => {
        "type" => "number",
        "description" => "First operand"
      },
      "b" => {
        "type" => "number",
        "description" => "Second operand"
      }
    },
    "required" => ["operation", "a", "b"]
  }
)

weather_tool = Google::ADK::FunctionTool.new(
  name: "get_weather",
  description: "Gets current weather for a location",
  callable: proc { |location:|
    # Simulated weather data
    weather_data = {
      "Seattle" => "Rainy, 55°F",
      "San Francisco" => "Foggy, 62°F",
      "New York" => "Sunny, 72°F",
      "London" => "Cloudy, 59°F"
    }
    
    weather_data[location] || "Weather data not available for #{location}"
  },
  parameters_schema: {
    "type" => "object",
    "properties" => {
      "location" => {
        "type" => "string",
        "description" => "City name"
      }
    },
    "required" => ["location"]
  }
)

# Create an agent with tools
assistant = Google::ADK::LlmAgent.new(
  name: "helpful_assistant",
  model: "gemini-2.0-flash",
  instructions: "You are a helpful assistant with access to calculator and weather tools. Use them when appropriate.",
  tools: [calculator_tool, weather_tool]
)

# Example of using another agent as a tool
specialist_agent = Google::ADK::LlmAgent.new(
  name: "ruby_expert",
  model: "gemini-2.0-flash",
  instructions: "You are a Ruby programming expert. Provide concise, accurate Ruby code examples."
)

# Main agent that can delegate to the specialist
main_agent = Google::ADK::LlmAgent.new(
  name: "general_assistant",
  model: "gemini-2.0-flash",
  instructions: "You help with general questions. For Ruby programming questions, use the ruby_expert tool.",
  tools: [specialist_agent, calculator_tool]
)

# Create runner
runner = Google::ADK::InMemoryRunner.new(
  agent: main_agent,
  app_name: "tool_demo"
)

# Example conversations
puts "Tool Usage Examples"
puts "=" * 50

# Example 1: Math calculation
puts "\nExample 1: Calculator Tool"
puts "-" * 30

events = runner.run(
  user_id: "demo_user",
  message: "What is 42 multiplied by 17?"
).to_a

events.select { |e| e.content }.each do |event|
  puts "[#{event.author}]: #{event.content}"
end

# Example 2: Using specialist agent as tool
puts "\n\nExample 2: Agent as Tool"
puts "-" * 30

events = runner.run(
  user_id: "demo_user",
  session_id: "session_2",
  message: "How do I create a Ruby class with a constructor?"
).to_a

events.select { |e| e.content }.each do |event|
  puts "[#{event.author}]: #{event.content}"
end

# Direct tool usage example
puts "\n\nExample 3: Direct Tool Usage"
puts "-" * 30

result = calculator_tool.call(operation: "divide", a: 100, b: 4)
puts "Direct calculation: 100 / 4 = #{result}"

weather = weather_tool.call(location: "Seattle")
puts "Weather check: #{weather}"