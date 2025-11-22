
export const Copy = {
  mounted() {
    let { to } = this.el.dataset;
    this.el.addEventListener("click", (ev) => {
      ev.preventDefault();
      let el = document.querySelector(to);
      if (!el) {
        console.error(`Element not found: ${to}`);
        return;
      }
      let text = el.textContent || el.innerText;
      navigator.clipboard.writeText(text);
    });
  },
};
