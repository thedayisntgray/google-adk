# frozen_string_literal: true

require "securerandom"
require "async"

module Google
  module ADK
    # Plugin base class for extending runner behavior
    class Plugin
      # Called when user sends a message
      #
      # @param context [InvocationContext] Current context
      # @param message [String] User message
      def on_user_message(context, message); end

      # Called for each event
      #
      # @param context [InvocationContext] Current context
      # @param event [Event] Current event
      def on_event(context, event); end

      # Called when agent starts
      #
      # @param context [InvocationContext] Current context
      def on_agent_start(context); end

      # Called when agent ends
      #
      # @param context [InvocationContext] Current context
      def on_agent_end(context); end
    end

    # Main runner for orchestrating agent execution
    class Runner
      attr_reader :agent, :app_name, :session_service, :plugins

      # Initialize a runner
      #
      # @param agent [BaseAgent] Root agent to run
      # @param app_name [String] Application name
      # @param session_service [BaseSessionService] Session service (optional)
      # @param plugins [Array<Plugin>] Runner plugins (optional)
      def initialize(agent:, app_name:, session_service: nil, plugins: [])
        @agent = agent
        @app_name = app_name
        @session_service = session_service || InMemorySessionService.new
        @plugins = plugins
      end

      # Run the agent synchronously
      #
      # @param user_id [String] User ID
      # @param session_id [String] Session ID (optional)
      # @param message [String] User message
      # @param new_session [Boolean] Force new session (optional)
      # @yield [Event] Events during execution
      # @return [Enumerator<Event>] Event stream
      def run(user_id:, message:, session_id: nil, new_session: false)
        Enumerator.new do |yielder|
          # Create or get session
          session = if session_id && !new_session
                      @session_service.get_session(
                        app_name: @app_name,
                        user_id: user_id,
                        session_id: session_id
                      )
                    end

          session ||= @session_service.create_session(
            app_name: @app_name,
            user_id: user_id
          )

          invocation_id = "inv-#{SecureRandom.uuid}"

          # Create invocation context
          context = InvocationContext.new(
            session: session,
            agent: @agent,
            invocation_id: invocation_id,
            session_service: @session_service
          )

          # Create and yield user event
          user_event = Event.new(
            invocation_id: invocation_id,
            author: "user",
            content: message
          )
          
          # Plugin callback
          @plugins.each { |p| p.on_user_message(context, message) }
          
          yielder << user_event
          context.add_event(user_event)
          @plugins.each { |p| p.on_event(context, user_event) }

          # Update session
          @session_service.append_event(
            app_name: @app_name,
            user_id: user_id,
            session_id: session.id,
            event: user_event
          )

          # Run agent
          @plugins.each { |p| p.on_agent_start(context) }

          begin
            agent_events = @agent.run_async(message, context: context)
            
            # Process agent events
            agent_events.each do |event|
              yielder << event
              context.add_event(event)
              @plugins.each { |p| p.on_event(context, event) }

              # Update session with event
              @session_service.append_event(
                app_name: @app_name,
                user_id: user_id,
                session_id: session.id,
                event: event
              )

              # Handle state updates from event actions
              if event.actions&.state_delta && !event.actions.state_delta.empty?
                @session_service.update_session(
                  app_name: @app_name,
                  user_id: user_id,
                  session_id: session.id,
                  state_updates: event.actions.state_delta
                )
              end

              # Handle agent transfers
              if event.actions&.transfer_to_agent
                # In a full implementation, would transfer to another agent
                break
              end
            end
          rescue StandardError => e
            # Create error event
            error_event = Event.new(
              invocation_id: invocation_id,
              author: "system",
              content: "Error: #{e.message}"
            )
            yielder << error_event
            context.add_event(error_event)
          ensure
            @plugins.each { |p| p.on_agent_end(context) }
          end
        end
      end

      # Run the agent asynchronously
      #
      # @param user_id [String] User ID
      # @param session_id [String] Session ID (optional)
      # @param message [String] User message
      # @param new_session [Boolean] Force new session (optional)
      # @return [Enumerator<Event>] Event stream
      def run_async(user_id:, message:, session_id: nil, new_session: false)
        # In this simplified version, we delegate to the sync method
        # In a full implementation, this would use Async gem for true async
        run(
          user_id: user_id,
          message: message,
          session_id: session_id,
          new_session: new_session
        )
      end

      # Run in live/streaming mode (experimental)
      #
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      def run_live(user_id:, session_id:)
        raise NotImplementedError, "Live mode not yet implemented"
      end

      # Rewind session to previous state
      #
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @param invocation_id [String] Invocation to rewind before
      def rewind_async(user_id:, session_id:, invocation_id:)
        raise NotImplementedError, "Rewind not yet implemented"
      end
    end

    # In-memory runner with built-in session service
    class InMemoryRunner < Runner
      # Initialize in-memory runner
      #
      # @param agent [BaseAgent] Root agent
      # @param app_name [String] Application name
      # @param plugins [Array<Plugin>] Runner plugins (optional)
      def initialize(agent:, app_name:, plugins: [])
        super(
          agent: agent,
          app_name: app_name,
          session_service: InMemorySessionService.new,
          plugins: plugins
        )
      end
    end
  end
end