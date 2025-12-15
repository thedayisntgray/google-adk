# frozen_string_literal: true

module Google
  module ADK
    # Base class for all tools
    class BaseTool
      attr_reader :name, :description

      # Initialize base tool
      #
      # @param name [String] Tool name (optional)
      # @param description [String] Tool description (optional)
      def initialize(name: nil, description: nil)
        @name = name
        @description = description
      end

      # Execute the tool with given parameters
      #
      # @param params [Hash] Tool parameters
      # @return [Object] Tool result
      def call(params = {})
        raise NotImplementedError, "Subclasses must implement #call"
      end

      # Get the tool's parameter schema
      #
      # @return [Hash] JSON schema for parameters
      def schema
        raise NotImplementedError, "Subclasses must implement #schema"
      end
    end
  end
end