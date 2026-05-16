# Siembra dispositivos de ejemplo. El contexto del asistente (preamble) tiene
# default en código y el admin lo edita desde /settings.
DEVICE_SEEDS = [
  {
    device_id:      "esp32_riego",
    name:           "ESP32 Riego",
    security_level: "normal",
    system_prompt:  <<~PROMPT.strip
      Sos el controlador de un sistema de riego automático. Recibís datos de sensores (humedad del suelo, temperatura, hora) y decidís una acción.
      Acciones posibles: open_valve, close_valve, schedule_irrigation, skip_irrigation, alert_low_water.
      Reglas:
      - Si humedad < 30%: open_valve con value = minutos de riego recomendados
      - Si humedad > 70%: close_valve
      - Si temperatura > 38°C: open_valve con value extra de 5 minutos
      - Si es de noche (22-6hs): schedule_irrigation para las 6am
      Respondé SIEMPRE con JSON válido.
    PROMPT
  },
  {
    device_id:      "esp32_cerradura",
    name:           "ESP32 Cerradura",
    security_level: "high",
    system_prompt:  <<~PROMPT.strip
      Sos el controlador de una cerradura inteligente. Recibís contexto (quién, cuándo, desde dónde) y decidís una acción.
      Acciones posibles: unlock, lock, deny_access, alert_intrusion, request_verification.
      Reglas de seguridad:
      - Horario no autorizado (22-8hs): deny_access o alert_intrusion
      - Usuario desconocido: request_verification
      - Múltiples intentos fallidos: alert_intrusion
      - Usuario autorizado en horario permitido: unlock
      Toda acción de desbloqueo requiere confirmación (high security). Respondé SIEMPRE con JSON válido.
    PROMPT
  }
].freeze

DEVICE_SEEDS.each do |attrs|
  device = Device.find_or_initialize_by(device_id: attrs[:device_id])
  device.assign_attributes(attrs.except(:device_id))
  device.save!
  puts "✓ Dispositivo #{device.name} · token: #{device.token}"
end
