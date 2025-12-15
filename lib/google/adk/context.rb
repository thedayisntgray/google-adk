# frozen_string_literal: true

module Google
  module ADK
    # Configuration for context caching
    class ContextCacheConfig
      attr_accessor :min_tokens, :ttl_seconds, :cache_intervals

      # Initialize cache configuration
      #
      # @param min_tokens [Integer] Minimum tokens to cache (default: 1024)
      # @param ttl_seconds [Integer] Cache TTL in seconds (default: 300)
      # @param cache_intervals [Array<Integer>] Cache intervals (default: [])
      def initialize(min_tokens: 1024, ttl_seconds: 300, cache_intervals: [])
        @min_tokens = min_tokens
        @ttl_seconds = ttl_seconds
        @cache_intervals = cache_intervals
      end
    end

    # Configuration for agent run
    class RunConfig
      attr_accessor :max_tokens, :temperature, :context_window_compression,
                    :max_steps, :timeout_seconds

      # Initialize run configuration
      #
      # @param max_tokens [Integer] Maximum tokens for response (optional)
      # @param temperature [Float] LLM temperature (default: 0.7)
      # @param context_window_compression [Boolean] Enable compression (default: false)
      # @param max_steps [Integer] Maximum execution steps (optional)
      # @param timeout_seconds [Integer] Execution timeout (optional)
      def initialize(max_tokens: nil, temperature: 0.7,
                     context_window_compression: false,
                     max_steps: nil, timeout_seconds: nil)
        @max_tokens = max_tokens
        @temperature = temperature
        @context_window_compression = context_window_compression
        @max_steps = max_steps
        @timeout_seconds = timeout_seconds
      end
    end

    # Read-only context for accessing state
    class ReadonlyContext
      attr_reader :invocation_id, :agent_name, :state

      # Initialize readonly context
      #
      # @param invocation_id [String] Unique invocation ID
      # @param agent_name [String] Current agent name
      # @param state [Hash] Current state (will be frozen)
      def initialize(invocation_id:, agent_name:, state:)
        @invocation_id = invocation_id
        @agent_name = agent_name
        @state = state.freeze
      end
    end

    # Context for callbacks with mutable state
    class CallbackContext < ReadonlyContext
      attr_reader :session

      # Initialize callback context
      #
      # @param invocation_id [String] Unique invocation ID
      # @param agent_name [String] Current agent name
      # @param session [Object] Session object with state
      def initialize(invocation_id:, agent_name:, session:)
        @invocation_id = invocation_id
        @agent_name = agent_name
        @session = session
      end

      # Get mutable state from session
      #
      # @return [Hash] Mutable state hash
      def state
        @session.state
      end

      # Update multiple state values
      #
      # @param updates [Hash] Key-value pairs to update
      def update_state(updates)
        state.merge!(updates)
      end
    end

    # Context for tool execution
    class ToolContext < CallbackContext
      attr_reader :auth_service, :artifact_service, :memory_service

      # Initialize tool context
      #
      # @param invocation_id [String] Unique invocation ID
      # @param agent_name [String] Current agent name
      # @param session [Object] Session object
      # @param auth_service [Object] Authentication service (optional)
      # @param artifact_service [Object] Artifact service (optional)
      # @param memory_service [Object] Memory service (optional)
      def initialize(invocation_id:, agent_name:, session:,
                     auth_service: nil, artifact_service: nil, memory_service: nil)
        super(invocation_id: invocation_id, agent_name: agent_name, session: session)
        @auth_service = auth_service
        @artifact_service = artifact_service
        @memory_service = memory_service
      end

      # Request authentication
      #
      # @param auth_type [String] Type of authentication
      # @param options [Hash] Authentication options
      def request_auth(auth_type, **options)
        raise AgentError, "Auth service not available" unless @auth_service

        @auth_service.request_auth(auth_type, options)
      end

      # List artifacts
      #
      # @return [Array] List of artifacts
      def list_artifacts
        return [] unless @artifact_service

        @artifact_service.list_artifacts
      end

      # Search memory
      #
      # @param query [String] Search query
      # @return [Array] Search results
      def search_memory(query)
        return [] unless @memory_service

        @memory_service.search(query)
      end
    end

    # Full invocation context for agent execution
    class InvocationContext
      attr_reader :session, :agent, :invocation_id, :session_service,
                  :artifact_service, :memory_service, :agent_states,
                  :context_cache_config, :run_config

      # Initialize invocation context
      #
      # @param session [Object] Current session
      # @param agent [BaseAgent] Current agent
      # @param invocation_id [String] Unique invocation ID
      # @param session_service [Object] Session service
      # @param artifact_service [Object] Artifact service (optional)
      # @param memory_service [Object] Memory service (optional)
      # @param context_cache_config [ContextCacheConfig] Cache config (optional)
      # @param run_config [RunConfig] Run configuration (optional)
      def initialize(session:, agent:, invocation_id:, session_service:,
                     artifact_service: nil, memory_service: nil,
                     context_cache_config: nil, run_config: nil)
        @session = session
        @agent = agent
        @invocation_id = invocation_id
        @session_service = session_service
        @artifact_service = artifact_service
        @memory_service = memory_service
        @agent_states = {}
        @context_cache_config = context_cache_config || ContextCacheConfig.new
        @run_config = run_config || RunConfig.new
      end

      # Get agent state
      #
      # @param agent_name [String] Agent name
      # @return [Hash] Agent state or empty hash
      def get_agent_state(agent_name)
        @agent_states[agent_name] || {}
      end

      # Update agent state
      #
      # @param agent_name [String] Agent name
      # @param state [Hash] New state
      def update_agent_state(agent_name, state)
        @agent_states[agent_name] = state
      end

      # Get current session state
      #
      # @return [Hash] Session state
      def state
        @session.state
      end

      # Update session state
      #
      # @param updates [Hash] State updates
      def update_state(updates)
        @session.state.merge!(updates)
      end

      # Add event to session
      #
      # @param event [Event] Event to add
      def add_event(event)
        @session.events << event
      end

      # Get conversation history
      #
      # @return [Array<Event>] Event history
      def events
        @session.events
      end

      # Create callback context
      #
      # @return [CallbackContext] Callback context
      def to_callback_context
        CallbackContext.new(
          invocation_id: @invocation_id,
          agent_name: @agent.name,
          session: @session
        )
      end

      # Create tool context
      #
      # @param auth_service [Object] Auth service (optional)
      # @return [ToolContext] Tool context
      def to_tool_context(auth_service: nil)
        ToolContext.new(
          invocation_id: @invocation_id,
          agent_name: @agent.name,
          session: @session,
          auth_service: auth_service,
          artifact_service: @artifact_service,
          memory_service: @memory_service
        )
      end
    end
  end
end