module Api
  module V1
    class ConversationsController < BaseController
      def index
        conversations = Conversation.recent
        render json: conversations.map { |c| serialize(c) }
      end

      def show
        conversation = Conversation.find(params[:id])
        render json: serialize(conversation, include_messages: true)
      end

      def create
        conversation = Conversation.new(conversation_params)

        if conversation.save
          render json: serialize(conversation), status: :created
        else
          render_error(conversation.errors.full_messages)
        end
      end

      private

      def conversation_params
        params.expect(conversation: %i[title provider model_id])
      end

      def serialize(conversation, include_messages: false)
        data = {
          id:         conversation.id,
          title:      conversation.title,
          provider:   conversation.provider,
          model_id:   conversation.model_id,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at
        }
        data[:messages] = conversation.chat_messages.map { |m| serialize_message(m) } if include_messages
        data
      end

      def serialize_message(message)
        {
          id:       message.id,
          role:     message.role,
          content:  message.content,
          model_id: message.model_id,
          created_at: message.created_at
        }
      end
    end
  end
end
