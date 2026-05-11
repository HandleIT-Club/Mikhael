import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel"]

  connect() {
    if (this.element.hasAttribute("data-modal-auto-open")) this.open()
  }

  open() {
    this.overlayTarget.classList.remove("hidden")
  }

  close() {
    this.overlayTarget.classList.add("hidden")
  }

  closeOnBackdrop(event) {
    if (!this.panelTarget.contains(event.target)) this.close()
  }
}
