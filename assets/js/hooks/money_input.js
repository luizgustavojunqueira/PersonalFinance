export const MoneyInput = {
  mounted() {
    this.setupInput();
    this.handleEvent("seed-money-input", ({ id, value }) => {
      if (this.el.id === id) {
        this.el.value = value;
      }
    });
  },

  updated() {
    const hiddenName = this.el.getAttribute("data-hidden-name");
    const hidden = document.querySelector(`input[name="${hiddenName}"]`);
    if (hidden && hidden.value && this.el.value === "") {
      let reais = hidden.value.replace(",", ".");
      let formatted = new Intl.NumberFormat("pt-BR", {
        style: "currency",
        currency: "BRL",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }).format(parseFloat(reais));
      this.el.value = formatted;
    }
  },

  setupInput() {
    this.el.addEventListener("input", (e) => {
      let cursorPos = this.el.selectionStart;
      let oldValueLength = this.el.value.length;

      let value = this.el.value.replace(/\D/g, "");

      if (value === "") {
        this.el.value = "";
        this.updateHidden("");
        return;
      }

      let cents = parseInt(value, 10);
      let reais = (cents / 100).toFixed(2);

      let formatted = new Intl.NumberFormat("pt-BR", {
        style: "currency",
        currency: "BRL",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }).format(parseFloat(reais));

      this.el.value = formatted;
      this.updateHidden(reais.replace(".", ","));

      let newValueLength = formatted.length;
      let lengthDiff = newValueLength - oldValueLength;
      let newCursorPos = cursorPos + lengthDiff;

      newCursorPos = Math.max(0, Math.min(newValueLength, newCursorPos));
      this.el.setSelectionRange(newCursorPos, newCursorPos);
    });
  },

  updateHidden(value) {
    const hiddenName = this.el.getAttribute("data-hidden-name");
    const hidden = document.querySelector(`input[name="${hiddenName}"]`);
    if (hidden) {
      hidden.value = value;
      hidden.dispatchEvent(new Event("input", { bubbles: true }));
    }
  },
};
