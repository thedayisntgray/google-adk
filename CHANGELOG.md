# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-14

### Initial Alpha Release

**DISCLAIMER**: This is an UNOFFICIAL Ruby port of Google's Agent Development Kit (ADK). This gem is not affiliated with, endorsed by, or maintained by Google.

### Added
- Core agent functionality with `LlmAgent` class for Gemini API integration
- `SimpleLLMAgent` for basic LLM interactions without complex features
- `FunctionTool` class for wrapping Ruby methods as callable tools
- Context management system for maintaining conversation history
- In-memory session storage for state management
- Event system foundation for streaming responses
- Comprehensive test suite with RSpec
- Full documentation with YARD

### Known Limitations
- This is an alpha release with limited functionality
- Only Gemini API is supported (no Anthropic, OpenAI, etc.)
- Workflow agents (Sequential, Parallel, Loop) are not yet fully implemented
- No production-ready error handling or retry logic
- Limited tool integration compared to Python SDK

### Dependencies
- Ruby >= 3.1.0
- async (~> 2.0)
- faraday (~> 2.0)
- concurrent-ruby (~> 1.2)
- google-cloud-ai_platform-v1 (~> 0.1)
- dotenv (~> 2.8)

### Installation
```ruby
gem 'google-adk', '~> 0.1.0'
```

### Example Usage
```ruby
require 'google-adk'

agent = Google::ADK::LlmAgent.new(
  model: 'gemini-2.0-flash',
  name: 'assistant',
  instructions: 'You are a helpful assistant'
)

response = agent.call("Hello, world!")
puts response
```

[0.1.0]: https://github.com/yourusername/google-adk-ruby/releases/tag/v0.1.0