# frozen_string_literal: true

require "securerandom"
require "time"

module Google
  module ADK
    # Represents a conversation session
    class Session
      attr_accessor :id, :app_name, :user_id, :state, :events, :last_update_time

      # Initialize a session
      #
      # @param id [String] Session ID
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param state [Hash] Session state (default: {})
      # @param events [Array<Event>] Session events (default: [])
      # @param last_update_time [Time] Last update timestamp (default: current time)
      def initialize(id:, app_name:, user_id:, state: {}, events: [], last_update_time: nil)
        @id = id
        @app_name = app_name
        @user_id = user_id
        @state = state
        @events = events
        @last_update_time = last_update_time || Time.now
      end

      # Convert to hash representation
      #
      # @return [Hash] Hash representation
      def to_h
        {
          id: @id,
          app_name: @app_name,
          user_id: @user_id,
          state: @state,
          events: @events.map(&:to_h),
          last_update_time: @last_update_time.iso8601
        }
      end

      # Create session from hash
      #
      # @param hash [Hash] Hash representation
      # @return [Session] New session instance
      def self.from_h(hash)
        new(
          id: hash[:id],
          app_name: hash[:app_name],
          user_id: hash[:user_id],
          state: hash[:state] || {},
          events: (hash[:events] || []).map { |e| Event.new(**e) },
          last_update_time: Time.parse(hash[:last_update_time])
        )
      end
    end

    # Base class for session services
    class BaseSessionService
      # Create a new session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param initial_state [Hash] Initial state (optional)
      # @return [Session] Created session
      def create_session(app_name: nil, user_id: nil, initial_state: nil)
        raise NotImplementedError, "Subclasses must implement #create_session"
      end

      # Get a session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @return [Session, nil] Session or nil if not found
      def get_session(app_name: nil, user_id: nil, session_id: nil)
        raise NotImplementedError, "Subclasses must implement #get_session"
      end

      # Update session state
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @param state_updates [Hash] State updates
      # @return [Session, nil] Updated session or nil if not found
      def update_session(app_name: nil, user_id: nil, session_id: nil, state_updates: nil)
        raise NotImplementedError, "Subclasses must implement #update_session"
      end

      # Append event to session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @param event [Event] Event to append
      # @return [Session, nil] Updated session or nil if not found
      def append_event(app_name: nil, user_id: nil, session_id: nil, event: nil)
        raise NotImplementedError, "Subclasses must implement #append_event"
      end

      # Delete a session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @return [Boolean] True if deleted, false otherwise
      def delete_session(app_name: nil, user_id: nil, session_id: nil)
        raise NotImplementedError, "Subclasses must implement #delete_session"
      end

      # List sessions for a user
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @return [Array<Session>] List of sessions
      def list_sessions(app_name: nil, user_id: nil)
        raise NotImplementedError, "Subclasses must implement #list_sessions"
      end
    end

    # In-memory session service for development/testing
    class InMemorySessionService < BaseSessionService
      def initialize
        # Structure: { app_name => { user_id => { session_id => session } } }
        @sessions = {}
        @user_state = {}
        @app_state = {}
      end

      # Create a new session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param initial_state [Hash] Initial state (optional)
      # @return [Session] Created session
      def create_session(app_name:, user_id:, initial_state: nil)
        session = Session.new(
          id: "session-#{SecureRandom.uuid}",
          app_name: app_name,
          user_id: user_id,
          state: initial_state || {}
        )

        # Ensure nested structure exists
        @sessions[app_name] ||= {}
        @sessions[app_name][user_id] ||= {}
        @sessions[app_name][user_id][session.id] = session

        session
      end

      # Get a session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @return [Session, nil] Session or nil if not found
      def get_session(app_name:, user_id:, session_id:)
        @sessions.dig(app_name, user_id, session_id)
      end

      # Update session state
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @param state_updates [Hash] State updates
      # @return [Session, nil] Updated session or nil if not found
      def update_session(app_name:, user_id:, session_id:, state_updates:)
        session = get_session(app_name: app_name, user_id: user_id, session_id: session_id)
        return nil unless session

        session.state.merge!(state_updates)
        session.last_update_time = Time.now
        session
      end

      # Append event to session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @param event [Event] Event to append
      # @return [Session, nil] Updated session or nil if not found
      def append_event(app_name:, user_id:, session_id:, event:)
        session = get_session(app_name: app_name, user_id: user_id, session_id: session_id)
        return nil unless session

        session.events << event
        session.last_update_time = Time.now
        session
      end

      # Delete a session
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param session_id [String] Session ID
      # @return [Boolean] True if deleted, false otherwise
      def delete_session(app_name:, user_id:, session_id:)
        return false unless @sessions.dig(app_name, user_id, session_id)

        @sessions[app_name][user_id].delete(session_id)
        true
      end

      # List sessions for a user
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @return [Array<Session>] List of sessions
      def list_sessions(app_name:, user_id:)
        sessions_hash = @sessions.dig(app_name, user_id)
        return [] unless sessions_hash

        sessions_hash.values
      end

      # Get user state
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @return [Hash] User state
      def get_user_state(app_name:, user_id:)
        @user_state.dig(app_name, user_id) || {}
      end

      # Update user state
      #
      # @param app_name [String] Application name
      # @param user_id [String] User ID
      # @param state_updates [Hash] State updates
      # @return [Hash] Updated user state
      def update_user_state(app_name:, user_id:, state_updates:)
        @user_state[app_name] ||= {}
        @user_state[app_name][user_id] ||= {}
        @user_state[app_name][user_id].merge!(state_updates)
      end

      # Get app state
      #
      # @param app_name [String] Application name
      # @return [Hash] App state
      def get_app_state(app_name:)
        @app_state[app_name] || {}
      end

      # Update app state
      #
      # @param app_name [String] Application name
      # @param state_updates [Hash] State updates
      # @return [Hash] Updated app state
      def update_app_state(app_name:, state_updates:)
        @app_state[app_name] ||= {}
        @app_state[app_name].merge!(state_updates)
      end
    end
  end
end