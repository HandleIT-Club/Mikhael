module Ai
  class BaseClient
    include Dry::Monads[:result]

    # @param messages [Array<Hash>] [{role:, content:}]
    # @param model [String]
    # @return [Result<AiResponse>]
    def chat(messages:, model:)
      raise NotImplementedError, "#{self.class} must implement #chat"
    end

    private

    def build_response(content, model, provider)
      Success(AiResponse.new(content: content, model: model, provider: provider))
    end
  end
end
