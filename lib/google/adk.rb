# frozen_string_literal: true

# DISCLAIMER: This is an UNOFFICIAL Ruby port of Google's Agent Development Kit (ADK).
# This gem is not affiliated with, endorsed by, or maintained by Google.
# It is a community-driven implementation based on the public Python ADK repository.
# Use at your own risk.

require_relative "adk/version"
require_relative "adk/agents/base_agent"
require_relative "adk/agents/llm_agent"
require_relative "adk/agents/workflow_agents/sequential_agent"
require_relative "adk/agents/workflow_agents/parallel_agent"
require_relative "adk/agents/workflow_agents/loop_agent"
require_relative "adk/events"
require_relative "adk/context"
require_relative "adk/session"
require_relative "adk/tools/base_tool"
require_relative "adk/tools/function_tool"
require_relative "adk/tools/agent_tool"
require_relative "adk/clients/gemini_client"
require_relative "adk/clients/anthropic_client"
require_relative "adk/clients/openrouter_client"
require_relative "adk/runner"

module Google
  module ADK
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AgentError < Error; end
    class ToolError < Error; end
  end
end
