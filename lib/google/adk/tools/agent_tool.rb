# frozen_string_literal: true

require_relative "base_tool"

module Google
  module ADK
    # Tool that wraps another agent
    class AgentTool < BaseTool
      attr_reader :agent

      # Initialize an agent tool
      #
      # @param agent [BaseAgent] The agent to wrap
      def initialize(agent:)
        super(name: agent.name, description: agent.description)
        @agent = agent
      end

      # Execute the wrapped agent
      #
      # @param params [Hash] Parameters (should include 'message')
      # @return [Object] Agent response
      def call(params = {})
        message = params[:message] || params["message"] || ""
        context = params[:context]

        # In a real implementation, this would run the agent
        # and collect its response
        if @agent.respond_to?(:run_async)
          # Collect all events from the agent
          events = []
          @agent.run_async(message, context: context).each do |event|
            events << event
          end

          # Return the last event's content as the result
          events.last&.content || "No response"
        else
          "Agent #{@agent.name} cannot be executed"
        end
      end

      # Get parameter schema
      #
      # @return [Hash] JSON schema for agent invocation
      def schema
        {
          "type" => "object",
          "properties" => {
            "message" => {
              "type" => "string",
              "description" => "Message to send to the agent"
            }
          },
          "required" => ["message"]
        }
      end
    end
  end
end