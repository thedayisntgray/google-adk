# frozen_string_literal: true

require_relative "base_tool"

module Google
  module ADK
    # Tool that wraps a Ruby callable (Proc, Method, etc.)
    class FunctionTool < BaseTool
      attr_reader :callable, :parameters_schema

      # Initialize a function tool
      #
      # @param name [String] Tool name
      # @param description [String] Tool description (optional)
      # @param callable [Proc, Method] The function to wrap
      # @param parameters_schema [Hash] JSON schema for parameters (optional)
      def initialize(name:, description: nil, callable:, parameters_schema: nil)
        super(name: name, description: description)
        @callable = callable
        @parameters_schema = parameters_schema # Don't default here, let to_gemini_schema handle it
      end

      # Execute the wrapped function
      #
      # @param params [Hash] Function parameters
      # @return [Object] Function result
      def call(params = {})
        if @callable.parameters.empty?
          @callable.call
        else
          # Convert hash params to keyword arguments if the callable expects them
          if expects_keyword_args?
            @callable.call(**params)
          else
            @callable.call(params)
          end
        end
      end

      # Get parameter schema
      #
      # @return [Hash] JSON schema
      def schema
        @parameters_schema
      end
      
      # Convert to Gemini API schema format
      #
      # @return [Hash] Gemini function declaration
      def to_gemini_schema
        # Try to infer parameters from method signature if no schema provided
        schema = @parameters_schema || infer_schema_from_callable
        
        {
          "name" => @name,
          "description" => @description || "Function tool",
          "parameters" => schema
        }
      end

      private

      # Check if callable expects keyword arguments
      #
      # @return [Boolean] True if expects kwargs
      def expects_keyword_args?
        @callable.parameters.any? { |type, _name| %i[key keyreq keyrest].include?(type) }
      end

      # Generate default schema
      #
      # @return [Hash] Default empty schema
      def default_schema
        {
          "type" => "object",
          "properties" => {},
          "required" => []
        }
      end
      
      # Infer schema from callable parameters
      #
      # @return [Hash] Inferred JSON schema
      def infer_schema_from_callable
        properties = {}
        required = []
        
        @callable.parameters.each do |type, name|
          next if type == :block
          
          param_name = name.to_s
          
          # Determine type based on parameter name patterns
          param_type = case param_name
                      when /amount|rate|fee|price|cost/
                        "number"
                      when /days|count|limit/
                        "integer"
                      else
                        "string"
                      end
          
          properties[param_name] = {
            "type" => param_type,
            "description" => generate_param_description(param_name)
          }
          
          # Required if it's a required positional or keyword arg
          if [:req, :keyreq].include?(type)
            required << param_name
          end
        end
        
        {
          "type" => "object",
          "properties" => properties,
          "required" => required
        }
      end
      
      # Generate descriptive parameter descriptions
      def generate_param_description(param_name)
        case param_name
        when "from"
          "Source currency code (e.g., USD, EUR, GBP)"
        when "to"
          "Target currency code (e.g., USD, EUR, GBP)"
        when "amount"
          "Amount of money to convert (number)"
        when "city"
          "City name for weather information"
        when "days"
          "Number of days for forecast (1-3)"
        else
          "Parameter: #{param_name}"
        end
      end
    end
  end
end