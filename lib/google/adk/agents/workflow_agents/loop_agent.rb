# frozen_string_literal: true

module Google
  module ADK
    # Agent that executes another agent in a loop
    class LoopAgent < BaseAgent
      attr_reader :agent, :loop_condition, :max_iterations

      # Initialize a loop agent
      #
      # @param name [String] Agent name
      # @param description [String] Agent description (optional)
      # @param agent [BaseAgent] Agent to execute in loop
      # @param loop_condition [Proc] Condition to continue loop (optional)
      # @param max_iterations [Integer] Maximum iterations (default: 10)
      # @param before_agent_callback [Proc] Callback before agent execution
      # @param after_agent_callback [Proc] Callback after agent execution
      def initialize(name:, agent:, description: nil, loop_condition: nil,
                     max_iterations: 10, before_agent_callback: nil,
                     after_agent_callback: nil)
        super(
          name: name,
          description: description || "Executes #{agent.name} in a loop",
          sub_agents: [agent],
          before_agent_callback: before_agent_callback,
          after_agent_callback: after_agent_callback
        )

        @agent = agent
        @loop_condition = loop_condition
        @max_iterations = max_iterations
      end

      # Run agent in a loop
      #
      # @param message [String] Initial message
      # @param context [InvocationContext] Invocation context
      # @yield [Event] Events during execution
      def run_async(message, context: nil)
        Enumerator.new do |yielder|
          invocation_id = context&.invocation_id || "loop-#{SecureRandom.uuid}"

          # Yield start event
          start_event = Event.new(
            invocation_id: invocation_id,
            author: @name,
            content: "Starting loop execution with agent #{@agent.name}"
          )
          yielder << start_event

          current_input = message
          iteration = 0
          last_result = nil

          # Loop while condition is met or until max iterations
          while iteration < @max_iterations
            # Check loop condition if provided
            if @loop_condition && !@loop_condition.call(last_result, iteration)
              break
            end

            # Yield iteration event
            iteration_event = Event.new(
              invocation_id: invocation_id,
              author: @name,
              content: "Iteration #{iteration + 1}/#{@max_iterations}"
            )
            yielder << iteration_event

            begin
              # Run the agent
              agent_output = nil
              if @agent.respond_to?(:run_async)
                @agent.run_async(current_input, context: context).each do |event|
                  yielder << event
                  # Capture last content as result
                  agent_output = event.content if event.content
                end
              else
                error_event = Event.new(
                  invocation_id: invocation_id,
                  author: @name,
                  content: "Agent #{@agent.name} does not implement run_async"
                )
                yielder << error_event
              end

              # Update for next iteration
              last_result = agent_output || current_input
              current_input = last_result
              iteration += 1

            rescue StandardError => e
              # Handle errors
              error_event = Event.new(
                invocation_id: invocation_id,
                author: @name,
                content: "Error in iteration #{iteration + 1}: #{e.message}"
              )
              yielder << error_event
              iteration += 1
            end
          end

          # Yield completion event
          end_event = Event.new(
            invocation_id: invocation_id,
            author: @name,
            content: "Completed loop execution after #{iteration} iterations. Final result: #{last_result}"
          )
          yielder << end_event
        end
      end
    end
  end
end