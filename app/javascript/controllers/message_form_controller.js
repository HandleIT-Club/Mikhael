import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }

  disable() {
    this.inputTarget.disabled = true
    this.submitTarget.disabled = true
  }

  reset() {
    this.inputTarget.disabled = false
    this.submitTarget.disabled = false
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }
}
