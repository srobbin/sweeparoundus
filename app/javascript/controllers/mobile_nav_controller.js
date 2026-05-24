import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ['panel', 'button'];
  }

  connect() {
    this.boundDocumentClick = this.handleDocumentClick.bind(this);
    this.boundKeyDown = this.handleKeyDown.bind(this);
    document.addEventListener('click', this.boundDocumentClick);
    document.addEventListener('keydown', this.boundKeyDown);
  }

  disconnect() {
    document.removeEventListener('click', this.boundDocumentClick);
    document.removeEventListener('keydown', this.boundKeyDown);
  }

  toggle() {
    const isOpen = this.panelTarget.classList.toggle('hidden') === false;

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', String(isOpen));
    }

    if (isOpen) {
      this.#closeSearchPanel();
      const firstLink = this.panelTarget.querySelector('a');
      if (firstLink) firstLink.focus();
    }
  }

  close() {
    if (this.panelTarget.classList.contains('hidden')) return;
    this.panelTarget.classList.add('hidden');
    if (this.hasButtonTarget) this.buttonTarget.setAttribute('aria-expanded', 'false');
  }

  handleDocumentClick(event) {
    if (this.panelTarget.classList.contains('hidden')) return;
    if (this.panelTarget.contains(event.target)) return;
    if (this.hasButtonTarget && this.buttonTarget.contains(event.target)) return;
    this.close();
  }

  handleKeyDown(event) {
    if (event.key !== 'Escape') return;
    if (this.panelTarget.classList.contains('hidden')) return;
    this.close();
    if (this.hasButtonTarget) this.buttonTarget.focus();
  }

  #closeSearchPanel() {
    const searchPanel = document.querySelector('[data-mobile-search-target="panel"]');
    const searchButton = document.querySelector('[data-mobile-search-target="button"]');
    if (searchPanel) searchPanel.classList.add('hidden');
    if (searchButton) searchButton.setAttribute('aria-expanded', 'false');
  }
}
