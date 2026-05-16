# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html

# Implementación no-op de la interfaz ChatBroadcaster. Para callers que no
# tienen UI Hotwire que actualizar — API JSON, jobs, y specs que quieren
# correr la operation sin verificar broadcasts.
#
# La interfaz tiene que mantenerse en sync con ChatBroadcaster.
class NullChatBroadcaster
  def append_message(*)               ; end
  def show_streaming_placeholder      ; end
  def stream_chunk(*)                 ; end
  def replace_streaming_placeholder(*) ; end
  def remove_streaming_placeholder    ; end
  def update_title(*)                 ; end
  def update_model_selector           ; end
end
