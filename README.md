# Google ADK (Ruby)

Ruby implementation of Google's Agent Development Kit for building AI agents.

[![Gem Version](https://badge.fury.io/rb/google-adk.svg)](https://badge.fury.io/rb/google-adk)
[![Build Status](https://github.com/yourusername/google-adk-ruby/workflows/CI/badge.svg)](https://github.com/yourusername/google-adk-ruby/actions)

> **⚠️ DISCLAIMER: This is an UNOFFICIAL Ruby port of Google's Agent Development Kit (ADK). This gem is not affiliated with, endorsed by, or maintained by Google. It is a community-driven implementation based on the public Python ADK repository. Use at your own risk.**

## Overview

Google ADK (Agent Development Kit) is a Ruby gem that provides a flexible framework for building, orchestrating, and deploying AI agents. It's a port of Google's Python ADK, bringing the same powerful agent capabilities to the Ruby ecosystem.

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

## Quick Start

### Simple Agent

```ruby
require 'google-adk'

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
runner.run(user_id: 'user123', message: 'Hello!') do |event|
  puts "[#{event.author}]: #{event.content}" if event.content
end
```

### Using Tools

```ruby
# Define a custom tool
calculator = Google::ADK::FunctionTool.new(
  name: 'calculator',
  description: 'Performs calculations',
  callable: proc { |expression:| eval(expression) }
)

# Create agent with tools
agent = Google::ADK::LlmAgent.new(
  name: 'math_assistant',
  model: 'gemini-2.0-flash',
  instructions: 'You help with math problems',
  tools: [calculator]
)
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
service = Google::ADK::InMemorySessionService.new
session = service.create_session(
  app_name: 'my_app',
  user_id: 'user123'
)
```

## Examples

See the `examples/` directory for more comprehensive examples:

- `basic_agent.rb` - Simple agent creation and usage
- `multi_agent_system.rb` - Complex multi-agent workflows
- `tool_usage.rb` - Custom tools and agent-as-tool patterns

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
# Run tests
bundle exec rake spec

# Run linter
bundle exec rubocop

# Build gem
bundle exec rake build
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/google-adk-ruby

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).