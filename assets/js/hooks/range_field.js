export const RangeField = {
  mounted() {
    this.readMetadata();
    this.buildTooltip();

    this.handleInput = (event) => {
      this.buildTooltip();
      this.syncValue(event);
      this.updateTooltip(event.target.value);
      this.showTooltip();
    };

    this.handlePointerDown = () => {
      this.buildTooltip();
      this.updateTooltip(this.el.value);
      this.showTooltip();
    };

    this.handleChange = (event) => {
      this.syncValue(event);
      this.updateTooltip(event.target.value);
      this.submitForm();
      this.hideTooltipDelayed();
    };

    this.updateProgress(this.el.value);
    this.updateTooltip(this.el.value);

    this.el.addEventListener("input", this.handleInput);
    this.el.addEventListener("change", this.handleChange);
    this.el.addEventListener("pointerdown", this.handlePointerDown);
  },

  updated() {
    this.readMetadata();
    this.buildTooltip();
    this.updateProgress(this.el.value);
    this.updateTooltip(this.el.value);
  },

  destroyed() {
    this.el.removeEventListener("input", this.handleInput);
    this.el.removeEventListener("change", this.handleChange);
    this.el.removeEventListener("pointerdown", this.handlePointerDown);

    if (this.tooltip?.parentNode) {
      this.tooltip.parentNode.removeChild(this.tooltip);
    }

    clearTimeout(this.tooltipTimeout);
  },

  readMetadata() {
    const datasetValue = this.el.dataset.maxAvailable;
    this.maxAvailable = datasetValue ? parseFloat(datasetValue) : null;
    this.form = this.el.form;
    this.shell = this.el.closest(".slider-shell") || this.el.parentElement;
  },

  syncValue(event) {
    let value = parseFloat(event.target.value);

    if (isNaN(value)) {
      value = 0;
    }

    if (this.maxAvailable != null && value > this.maxAvailable) {
      value = this.maxAvailable;
      event.target.value = value;
    }

    if (value < 0) {
      value = 0;
      event.target.value = value;
    }

    this.updateProgress(value);
  },

  submitForm() {
    if (this.form && !this.el.disabled) {
      this.form.requestSubmit();
    }
  },

  buildTooltip() {
    if (!this.shell) return;

    if (this.tooltip && !this.tooltip.isConnected) {
      this.tooltip = null;
    }

    if (!this.tooltip) {
      this.tooltip = document.createElement("div");
      this.tooltip.className = "category-slider-tooltip";
      this.tooltip.textContent = this.formatValue(this.el.value);
    }

    if (this.tooltip.parentNode !== this.shell) {
      this.shell.appendChild(this.tooltip);
    }
  },

  updateTooltip(value) {
    if (!this.tooltip) return;

    const formatted = this.formatValue(value);
    this.tooltip.textContent = formatted;
    this.positionTooltip(parseFloat(value));
  },

  positionTooltip(value) {
    if (!this.tooltip || !this.shell) return;

    const min = parseFloat(this.el.min || "0");
    const max = parseFloat(this.el.max || "100");
    const numericValue = isNaN(value) ? min : value;
    const percent = (numericValue - min) / (max - min);
    const clamped = Math.min(Math.max(percent, 0), 1);
    const sliderWidth = this.el.offsetWidth;
    const left = clamped * sliderWidth;

    this.tooltip.style.left = `${left}px`;
    this.tooltip.style.transform = "translate(-50%, 0)";
  },

  showTooltip() {
    if (this.tooltip) {
      this.tooltip.classList.add("visible");
    }
  },

  hideTooltipDelayed() {
    clearTimeout(this.tooltipTimeout);
    this.tooltipTimeout = setTimeout(() => {
      if (this.tooltip) {
        this.tooltip.classList.remove("visible");
      }
    }, 400);
  },

  formatValue(value) {
    const number = parseFloat(value);
    if (isNaN(number)) {
      return "0%";
    }

    return `${number.toFixed(2)}%`;
  },

  updateProgress(value) {
    const numericValue = parseFloat(value) || 0;
    this.el.style.setProperty("--slider-progress", `${numericValue}%`);
  },
};
