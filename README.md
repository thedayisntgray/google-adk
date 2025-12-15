# Google ADK (Ruby)

Ruby implementation of Google's Agent Development Kit for building AI agents.

[![Gem Version](https://badge.fury.io/rb/google-adk.svg)](https://badge.fury.io/rb/google-adk)
[![Build Status](https://github.com/yourusername/google-adk-ruby/workflows/CI/badge.svg)](https://github.com/yourusername/google-adk-ruby/actions)

> **⚠️ DISCLAIMER: This is an UNOFFICIAL Ruby port of Google's Agent Development Kit (ADK). This gem is not affiliated with, endorsed by, or maintained by Google. It is a community-driven implementation based on the public Python ADK repository. Use at your own risk.**

## Overview

Google ADK (Agent Development Kit) is a Ruby gem that provides a flexible framework for building, orchestrating, and deploying AI agents. It's a port of Google's Python ADK, bringing the same powerful agent capabilities to the Ruby ecosystem.

### Prerequisites

- Ruby 3.1 or higher
- Gemini API account and API key ([Get one here](https://makersuite.google.com/app/apikey))
- Bundler gem for dependency management

### Key Features

- **Multiple Agent Types**: LLM agents, sequential, parallel, and loop workflow agents
- **Tool Integration**: Easy integration of custom tools and functions
- **Event-Driven Architecture**: Stream events for real-time agent interactions
- **Session Management**: Built-in session and state management
- **Flexible Orchestration**: Run agents individually or compose them into complex workflows
- **Plugin System**: Extend functionality with custom plugins

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'google-adk'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install google-adk
```

### Configuration

Set your Gemini API key before using the gem:

```bash
# Via environment variable (recommended)
export GEMINI_API_KEY="your-api-key-here"
```

Or configure programmatically:

```ruby
require 'google-adk'

Google::ADK.configure do |config|
  config.api_key = "your-api-key-here"
  config.default_model = "gemini-2.0-flash"  # optional, defaults to gemini-2.0-flash
  config.timeout = 30  # optional, request timeout in seconds
end
```

## Quick Start

### Complete Working Example

```ruby
require 'google-adk'

# Ensure API key is set
ENV['GEMINI_API_KEY'] ||= 'your-api-key-here'

# Create an agent
agent = Google::ADK::LlmAgent.new(
  name: 'assistant',
  model: 'gemini-2.0-flash',
  instructions: 'You are a helpful assistant'
)

# Run with a runner
runner = Google::ADK::InMemoryRunner.new(
  agent: agent,
  app_name: 'my_app'
)

# Execute and stream events
runner.run(user_id: 'user123', message: 'What is the capital of France?') do |event|
  case event
  when Google::ADK::Event
    puts "[#{event.author}]: #{event.content}" if event.content
  when Google::ADK::ToolCallEvent
    puts "Tool called: #{event.tool_name}"
  when Google::ADK::ErrorEvent
    puts "Error: #{event.error_message}"
  end
end

# Expected output:
# [assistant]: The capital of France is Paris.
```

### Blocking vs Streaming

```ruby
# Streaming (with block) - events arrive in real-time
runner.run(user_id: 'user123', message: 'Hello!') do |event|
  puts "[#{event.author}]: #{event.content}" if event.content
end

# Blocking - wait for all events and return result
result = runner.run(user_id: 'user123', message: 'Hello!')
puts result.last.content  # Get the final response
```

### Using Tools

```ruby
# Define a custom tool with parameters
calculator = Google::ADK::FunctionTool.new(
  name: 'calculator',
  description: 'Performs calculations',
  callable: proc { |expression:| eval(expression) },
  parameters: {
    type: 'object',
    properties: {
      expression: {
        type: 'string',
        description: 'Mathematical expression to evaluate'
      }
    },
    required: ['expression']
  }
)

# Weather lookup tool
weather_tool = Google::ADK::FunctionTool.new(
  name: 'get_weather',
  description: 'Get current weather for a location',
  callable: proc do |location:, units: 'celsius'|
    # Your weather API call here
    "It's 22°#{units[0].upcase} and sunny in #{location}"
  end,
  parameters: {
    type: 'object',
    properties: {
      location: { type: 'string', description: 'City name' },
      units: { type: 'string', enum: ['celsius', 'fahrenheit'], default: 'celsius' }
    },
    required: ['location']
  }
)

# Create agent with tools
agent = Google::ADK::LlmAgent.new(
  name: 'math_assistant',
  model: 'gemini-2.0-flash',
  instructions: 'You help with math problems and weather queries',
  tools: [calculator, weather_tool]
)

# The agent will automatically call tools when needed
runner = Google::ADK::InMemoryRunner.new(agent: agent, app_name: 'my_app')
runner.run(user_id: 'user123', message: 'What is 25 * 4?') do |event|
  puts "[#{event.author}]: #{event.content}" if event.content
end
```

### Workflow Agents

```ruby
# Sequential workflow
research_agent = Google::ADK::LlmAgent.new(name: 'researcher', model: 'gemini-2.0-flash')
writer_agent = Google::ADK::LlmAgent.new(name: 'writer', model: 'gemini-2.0-flash')

sequential = Google::ADK::SequentialAgent.new(
  name: 'report_builder',
  agents: [research_agent, writer_agent]
)

# Parallel execution
parallel = Google::ADK::ParallelAgent.new(
  name: 'multi_analyzer',
  agents: [agent1, agent2, agent3],
  aggregation_strategy: :all
)

# Loop execution
loop_agent = Google::ADK::LoopAgent.new(
  name: 'refiner',
  agent: refiner_agent,
  max_iterations: 3
)
```

### Error Handling

```ruby
begin
  runner.run(user_id: 'user123', message: 'Hello!') do |event|
    puts "[#{event.author}]: #{event.content}" if event.content
  end
rescue Google::ADK::ConfigurationError => e
  puts "Configuration error: #{e.message}"
rescue Google::ADK::AgentError => e
  puts "Agent error: #{e.message}"
rescue Google::ADK::ToolError => e
  puts "Tool error: #{e.message}"
rescue Google::ADK::Error => e
  puts "General ADK error: #{e.message}"
end
```

## Core Concepts

### Agents

Agents are the fundamental building blocks:

- **BaseAgent**: Abstract base class for all agents
- **LlmAgent**: Language model-powered agent for conversations
- **SequentialAgent**: Executes sub-agents in sequence
- **ParallelAgent**: Executes sub-agents in parallel
- **LoopAgent**: Executes an agent in a loop

### Events

All agent interactions produce events that flow through the system:

```ruby
event = Google::ADK::Event.new(
  invocation_id: 'inv-123',
  author: 'assistant',
  content: 'Hello! How can I help?'
)
```

### Context

Context manages conversation state and agent lifecycle:

```ruby
context = Google::ADK::InvocationContext.new(
  session: session,
  agent: agent,
  invocation_id: 'inv-123',
  session_service: service
)
```

### Sessions

Sessions persist conversation history and state:

```ruby
# In-memory session (development)
service = Google::ADK::InMemorySessionService.new
session = service.create_session(
  app_name: 'my_app',
  user_id: 'user123'
)

# Database-backed session (production)
# service = Google::ADK::PostgresSessionService.new(
#   connection_string: ENV['DATABASE_URL']
# )

# Sessions include:
# - Conversation history
# - User state
# - Agent context
# - Tool call history

# Retrieve existing session
session = service.get_session(session_id: session.id)

# Update session state
session.state[:user_preference] = 'dark_mode'
service.update_session(session)
```

## Supported Models

Google ADK supports the following Gemini models:

- `gemini-2.0-flash` - Fast, efficient model (recommended for most use cases)
- `gemini-1.5-flash` - Previous generation fast model
- `gemini-1.5-pro` - More capable model for complex tasks
- `gemini-pro` - Legacy model

```ruby
# Use different models
agent = Google::ADK::LlmAgent.new(
  name: 'assistant',
  model: 'gemini-1.5-pro',  # For complex reasoning tasks
  instructions: 'You are an expert analyst'
)
```

## Examples

See the `examples/` directory for more comprehensive examples:

- `basic_agent.rb` - Simple agent creation and usage
- `multi_agent_system.rb` - Complex multi-agent workflows
- `tool_usage.rb` - Custom tools and agent-as-tool patterns

## Production Deployment

### Environment Variables

Configure your production environment:

```bash
# Required
GEMINI_API_KEY=your-production-api-key

# Optional
ADK_LOG_LEVEL=info           # debug, info, warn, error
ADK_REQUEST_TIMEOUT=30        # API request timeout in seconds
ADK_MAX_RETRIES=3            # Number of retries for failed requests
ADK_SESSION_CACHE_SIZE=1000  # Maximum sessions to keep in memory
```

### Logging

```ruby
# Configure logging
Google::ADK.configure do |config|
  config.logger = Logger.new(STDOUT)
  config.log_level = :info
end

# Or use Rails logger
Google::ADK.configure do |config|
  config.logger = Rails.logger
end
```

### Performance Tuning

```ruby
# Connection pooling for high-traffic applications
Google::ADK.configure do |config|
  config.connection_pool_size = 25
  config.connection_timeout = 5
end

# Enable response caching
Google::ADK.configure do |config|
  config.enable_cache = true
  config.cache_ttl = 300  # 5 minutes
end
```

## Debugging and Troubleshooting

### Enable Debug Mode

```ruby
# Enable debug logging
Google::ADK.configure do |config|
  config.debug = true
  config.log_level = :debug
end

# Debug specific components
ENV['ADK_DEBUG'] = 'true'
ENV['ADK_DEBUG_TOOLS'] = 'true'
ENV['ADK_DEBUG_EVENTS'] = 'true'
```

### Common Issues

**API Key Not Found**
```
Google::ADK::ConfigurationError: API key not configured
```
Solution: Set `GEMINI_API_KEY` environment variable or configure it in code.

**Rate Limiting**
```
Google::ADK::RateLimitError: Rate limit exceeded
```
Solution: Implement exponential backoff or reduce request frequency.

**Tool Execution Errors**
```
Google::ADK::ToolError: Tool 'calculator' failed to execute
```
Solution: Check tool parameter schema and ensure callable returns expected format.

**Session Not Found**
```
Google::ADK::SessionError: Session not found
```
Solution: Ensure session service is properly configured and session ID is valid.

### Getting Help

- **Documentation**: Full API docs at [RubyDoc.info](https://rubydoc.info/gems/google-adk)
- **GitHub Issues**: Report bugs at https://github.com/yourusername/google-adk-ruby/issues
- **Discord Community**: Join our Discord at https://discord.gg/google-adk-ruby
- **Stack Overflow**: Tag questions with `google-adk-ruby`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
# Run tests
bundle exec rake spec

# Run linter
bundle exec rubocop

# Build gem
bundle exec rake build

# Run with verbose output
ADK_DEBUG=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/google/adk/llm_agent_spec.rb

# Generate coverage report
COVERAGE=true bundle exec rake spec
open coverage/index.html
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/google-adk-ruby

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).