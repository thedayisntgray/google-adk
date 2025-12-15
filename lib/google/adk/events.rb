# frozen_string_literal: true

require "securerandom"
require "time"
require "set"

module Google
  module ADK
    # Represents a function call in an event
    class FunctionCall
      attr_reader :id, :name, :arguments

      # Initialize a function call
      #
      # @param id [String] Unique identifier for the call (optional)
      # @param name [String] Function name
      # @param arguments [Hash] Function arguments
      def initialize(id: nil, name:, arguments:)
        @id = id || "call-#{SecureRandom.uuid}"
        @name = name
        @arguments = arguments
      end

      # Convert to hash
      #
      # @return [Hash] Hash representation
      def to_h
        {
          id: @id,
          name: @name,
          arguments: @arguments
        }
      end
    end

    # Represents a function response in an event
    class FunctionResponse
      attr_reader :id, :name, :response, :is_error

      # Initialize a function response
      #
      # @param id [String] ID of the function call this responds to
      # @param name [String] Function name
      # @param response [Hash] Function response
      # @param is_error [Boolean] Whether this is an error response
      def initialize(id:, name:, response:, is_error: false)
        @id = id
        @name = name
        @response = response
        @is_error = is_error
      end

      # Convert to hash
      #
      # @return [Hash] Hash representation
      def to_h
        {
          id: @id,
          name: @name,
          response: @response,
          is_error: @is_error
        }
      end
    end

    # Manages agent actions and state changes
    class EventActions
      attr_accessor :state_delta, :agent_state, :artifact_delta,
                    :transfer_to_agent, :escalate, :skip_summarization,
                    :end_of_agent, :requested_auth_configs,
                    :requested_tool_confirmations, :rewind_before_invocation_id,
                    :compaction

      # Initialize event actions
      #
      # @param state_delta [Hash] State changes (optional)
      # @param agent_state [Hash] Agent-specific state (optional)
      # @param artifact_delta [Hash] Artifact changes (optional)
      # @param transfer_to_agent [String] Agent to transfer to (optional)
      # @param escalate [Boolean] Whether to escalate to parent (optional)
      # @param skip_summarization [Boolean] Skip LLM summarization (optional)
      # @param end_of_agent [Boolean] End agent lifecycle (optional)
      def initialize(state_delta: {}, agent_state: nil, artifact_delta: {},
                     transfer_to_agent: nil, escalate: false,
                     skip_summarization: false, end_of_agent: false,
                     requested_auth_configs: nil, requested_tool_confirmations: nil,
                     rewind_before_invocation_id: nil, compaction: nil)
        @state_delta = state_delta
        @agent_state = agent_state
        @artifact_delta = artifact_delta
        @transfer_to_agent = transfer_to_agent
        @escalate = escalate
        @skip_summarization = skip_summarization
        @end_of_agent = end_of_agent
        @requested_auth_configs = requested_auth_configs
        @requested_tool_confirmations = requested_tool_confirmations
        @rewind_before_invocation_id = rewind_before_invocation_id
        @compaction = compaction
      end

      # Convert to hash, excluding nil and empty values
      #
      # @return [Hash] Hash representation
      def to_h
        result = {}
        result[:state_delta] = @state_delta unless @state_delta.empty?
        result[:agent_state] = @agent_state unless @agent_state.nil?
        result[:artifact_delta] = @artifact_delta unless @artifact_delta.empty?
        result[:transfer_to_agent] = @transfer_to_agent unless @transfer_to_agent.nil?
        result[:escalate] = @escalate if @escalate
        result[:skip_summarization] = @skip_summarization if @skip_summarization
        result[:end_of_agent] = @end_of_agent if @end_of_agent
        result[:requested_auth_configs] = @requested_auth_configs unless @requested_auth_configs.nil?
        result[:requested_tool_confirmations] = @requested_tool_confirmations unless @requested_tool_confirmations.nil?
        result[:rewind_before_invocation_id] = @rewind_before_invocation_id unless @rewind_before_invocation_id.nil?
        result[:compaction] = @compaction unless @compaction.nil?
        result
      end
    end

    # Represents an event in agent-user conversation
    class Event
      attr_reader :id, :invocation_id, :author, :timestamp, :content,
                  :function_calls, :function_responses, :long_running_tool_ids,
                  :branch, :actions

      # Initialize an event
      #
      # @param id [String] Unique event identifier (optional)
      # @param invocation_id [String] Invocation ID
      # @param author [String] Event author (user or agent name)
      # @param timestamp [Time] Event timestamp (optional)
      # @param content [String] Event content (optional)
      # @param function_calls [Array<FunctionCall>] Function calls (optional)
      # @param function_responses [Array<FunctionResponse>] Function responses (optional)
      # @param long_running_tool_ids [Set] Long-running tool IDs (optional)
      # @param branch [String] Conversation branch (optional)
      # @param actions [EventActions] Event actions (optional)
      def initialize(invocation_id:, author:, id: nil, timestamp: nil,
                     content: nil, function_calls: [], function_responses: [],
                     long_running_tool_ids: nil, branch: nil, actions: nil)
        @id = id || self.class.new_id
        @invocation_id = invocation_id
        @author = author
        @timestamp = timestamp || Time.now
        @content = content
        @function_calls = function_calls
        @function_responses = function_responses
        @long_running_tool_ids = long_running_tool_ids || Set.new
        @branch = branch
        @actions = actions
      end

      # Check if this is a final response
      #
      # @return [Boolean] True if final response
      def is_final_response?
        return true if @author == "user"
        return true if @actions.nil?

        @actions.transfer_to_agent.nil?
      end

      # Generate a new event ID
      #
      # @return [String] New UUID-based ID
      def self.new_id
        SecureRandom.uuid
      end

      # Convert to hash representation
      #
      # @return [Hash] Hash representation
      def to_h
        result = {
          id: @id,
          invocation_id: @invocation_id,
          author: @author,
          timestamp: @timestamp.iso8601,
          content: @content,
          function_calls: @function_calls.map(&:to_h),
          function_responses: @function_responses.map(&:to_h),
          long_running_tool_ids: @long_running_tool_ids.to_a
        }
        result[:branch] = @branch unless @branch.nil?
        result[:actions] = @actions.to_h if @actions
        result
      end
    end
  end
end