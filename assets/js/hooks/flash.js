
export const FlashAutoClose = {
  mounted() {
    this.timeout = null;
    this.scheduleClose();
  },
  updated() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
    this.scheduleClose();
  },
  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  },
  scheduleClose() {
    clearTimeout(this.timeout);
    const autoCloseTime = parseInt(this.el.dataset.autoClose);
    if (autoCloseTime) {
      this.timeout = setTimeout(() => {
        const closeButton = this.el.querySelector(
          "button[aria-label='close']",
        );
        if (closeButton) {
          closeButton.click();
        } else {
          this.el.remove();
        }
      }, autoCloseTime);
    }
  },
};
