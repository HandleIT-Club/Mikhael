import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "loading"]

  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.messagesTarget, { childList: true, subtree: true })

    this.element.addEventListener("turbo:submit-start", () => this.showLoading())
    this.element.addEventListener("turbo:submit-end", () => this.hideLoading())
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  showLoading() {
    this.loadingTarget.classList.remove("hidden")
    this.scrollToBottom()
  }

  hideLoading() {
    this.loadingTarget.classList.add("hidden")
  }
}
