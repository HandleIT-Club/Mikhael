# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class DevicesController < ApplicationController
  before_action :set_device, only: %i[update destroy regenerate_token command]

  def index
    @devices = Device.order(:name)
    @new_device = Device.new
    @reveal_token = flash[:reveal_token]
    @reveal_device_id = flash[:reveal_device_id]
  end

  def create
    @device = Device.new(device_params)
    if @device.save
      redirect_to devices_path,
                  notice: "Dispositivo creado. Guardá el token — solo se muestra una vez.",
                  flash: { reveal_token: @device.token, reveal_device_id: @device.id }
    else
      @devices = Device.order(:name)
      @new_device = @device
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @device.update(device_params)
      redirect_to devices_path, notice: "#{@device.name} actualizado."
    else
      redirect_to devices_path, alert: @device.errors.full_messages.to_sentence
    end
  end

  def destroy
    @device.destroy
    redirect_to devices_path, status: :see_other
  end

  def command
    message = params[:message].to_s.strip
    @last_message = message

    if message.blank?
      @command_error = "El mensaje no puede estar vacío."
    else
      result = DispatchAction.new.call(device: @device, context: message, trusted: true)
      result.either(
        ->(response) { @command_result = response; MqttPublisher.publish(@device, response) },
        ->(_error)   { @command_error  = "No se pudo obtener una respuesta. Intentá de nuevo." }
      )
    end

    render turbo_stream: turbo_stream.replace(
      "device-cmd-#{@device.id}",
      partial: "devices/command_frame",
      locals:  { device: @device, result: @command_result, error: @command_error, last_message: @last_message }
    )
  end

  def regenerate_token
    @device.regenerate_token!
    redirect_to devices_path,
                notice: "Token regenerado. Guardalo — solo se muestra una vez.",
                flash: { reveal_token: @device.token, reveal_device_id: @device.id }
  end

  private

  def set_device
    @device = Device.find(params[:id])
  end

  def device_params
    params.expect(device: %i[device_id name system_prompt security_level actions])
  end
end
