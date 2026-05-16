# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
module Api
  module V1
    class DevicesController < BaseController
      include AdminAuthorization

      rate_limit to:     ENV.fetch("RATE_LIMIT_MESSAGES_PER_MIN", "30").to_i,
                 within: 1.minute,
                 by:     -> { request.remote_ip },
                 with:   -> { render_rate_limit_exceeded(30, identifier: request.remote_ip) },
                 store:  RATE_LIMIT_STORE,
                 only:   :command

      before_action :require_admin!
      before_action :set_device, only: %i[update destroy regenerate_token command]

      def index
        render json: Device.all.order(:name).map { |d| serialize(d) }
      end

      def create
        device = Device.new(device_params)
        if device.save
          render json: serialize(device, expose_token: true), status: :created
        else
          render_error(device.errors.full_messages)
        end
      end

      def update
        if @device.update(device_params)
          render json: serialize(@device)
        else
          render_error(@device.errors.full_messages)
        end
      end

      def destroy
        @device.destroy
        head :no_content
      end

      def regenerate_token
        @device.regenerate_token!
        render json: serialize(@device, expose_token: true)
      end

      def command
        message = params[:message].to_s.strip
        return render json: { error: "message es requerido" }, status: :unprocessable_entity if message.blank?

        result = DispatchAction.new.call(device: @device, context: message, trusted: true)
        result.either(
          ->(response) { MqttPublisher.publish(@device, response); render json: response },
          ->(error)    { render json: { error: error }, status: :service_unavailable }
        )
      end

      private

      def set_device
        @device = Device.find(params[:id])
      end

      def device_params
        params.expect(device: %i[device_id name system_prompt security_level actions])
      end

      def serialize(device, expose_token: false)
        data = {
          id:             device.id,
          device_id:      device.device_id,
          name:           device.name,
          system_prompt:  device.system_prompt,
          security_level: device.security_level,
          actions:        device.actions_list,
          online:         device.online?,
          last_seen_at:   device.last_seen_at,
          created_at:     device.created_at
        }
        data[:token] = device.token if expose_token
        data
      end
    end
  end
end
