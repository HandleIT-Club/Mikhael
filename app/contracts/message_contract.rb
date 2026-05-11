class MessageContract < Dry::Validation::Contract
  params do
    required(:content).filled(:string)
    required(:conversation_id).filled(:integer)
  end

  rule(:content) do
    key.failure("no puede estar vacío") if value.strip.empty?
  end
end
