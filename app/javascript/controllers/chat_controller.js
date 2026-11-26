import { Controller } from "@hotwired/stimulus"

// Keeps the conversation scrolled to the newest message and focuses the input.
export default class extends Controller {
  static targets = ["messages", "input"]

  connect() {
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.messagesTarget, { childList: true })
    this.scrollToBottom()
  }

  disconnect() {
    this.observer.disconnect()
  }

  inputTargetConnected(input) {
    input.focus()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
