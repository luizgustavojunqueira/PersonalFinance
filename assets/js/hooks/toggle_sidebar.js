
export const ToggleSidebar = {
  mounted() {
    const sidebar = document.getElementById("sidebar");

    this.el.addEventListener("click", () => {
      sidebar.classList.toggle("expanded");
    });
  },
};
