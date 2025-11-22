
export const Modal = {
  mounted() {
    const id = this.el.id;
    this.handleEvent(`open_modal:${id}`, () => {
      console.log(id);
      document.getElementById(id)?.showModal();
    });
    this.handleEvent(`close_modal:${id}`, () => {
      document.getElementById(id)?.close();
    });
  },

  updated() {
    if (!this.el.open) this.el.showModal();
  },
};
