
export const ColorPicker = {
  mounted() {
    const input = this.el;
    const colorDisplay = document.getElementById(
      input.dataset.colorDisplayId,
    );
    input.addEventListener("input", (event) => {
      colorDisplay.style.backgroundColor = event.target.value;
    });
  },
};
