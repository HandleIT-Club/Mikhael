class AiResponse < Dry::Struct
  attribute :content,  Types::Strict::String
  attribute :model,    Types::Strict::String
  attribute :provider, Types::Strict::String
end
