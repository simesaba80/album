import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  connect() {
    if (this.rowCount === 0) this.addRow()
  }

  onFileChange(event) {
    const input = event.currentTarget
    const row = input.closest("[data-photo-inputs-row]")
    if (!row) return

    if (this.isLastRow(row) && this.hasSelectedFile(input)) {
      this.addRow()
    }
  }

  removeRow(event) {
    const row = event.currentTarget.closest("[data-photo-inputs-row]")
    if (!row) return

    row.remove()

    if (this.rowCount === 0 || this.lastRowFilled()) {
      this.addRow()
    }
  }

  addRow() {
    const node = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.listTarget.appendChild(node)
  }

  get rows() {
    return this.listTarget.querySelectorAll("[data-photo-inputs-row]")
  }

  get rowCount() {
    return this.rows.length
  }

  isLastRow(row) {
    const rows = this.rows
    return rows.length > 0 && rows[rows.length - 1] === row
  }

  hasSelectedFile(input) {
    return input.files && input.files.length > 0
  }

  lastRowFilled() {
    const rows = this.rows
    if (rows.length === 0) return false

    const lastInput = rows[rows.length - 1].querySelector('input[type="file"]')
    return lastInput ? this.hasSelectedFile(lastInput) : false
  }
}
