// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import Chart from "chart.js/auto";
import topbar from "../vendor/topbar";

let Hooks = {};

Hooks.ToggleSidebar = {
    mounted() {
        const sidebar = document.getElementById("sidebar");
        const btn = document.getElementById("toggle-sidebar");
        const openIcon = this.el.querySelector(".open-icon");
        const closeIcon = this.el.querySelector(".close-icon");

        let isOpen = localStorage.getItem("sidebarOpen") === "true";

        this.updateSidebarState(sidebar, openIcon, closeIcon, btn, isOpen);

        this.el.addEventListener("click", () => {
            isOpen = !isOpen;
            localStorage.setItem("sidebarOpen", isOpen);
            this.updateSidebarState(sidebar, openIcon, closeIcon, btn, isOpen);
        });
    },

    updateSidebarState(sidebar, openIcon, closeIcon, btn, isOpen) {
        if (isOpen) {
            sidebar.classList.remove("collapsed");
            openIcon.classList.add("hidden");
            closeIcon.classList.remove("hidden");
            btn.classList.remove("collapsed");
        } else {
            sidebar.classList.add("collapsed");
            openIcon.classList.remove("hidden");
            closeIcon.classList.add("hidden");
            btn.classList.add("collapsed");
        }
    },
};

Hooks.ChartJS = {
    dataset() {
        return;
    },
    mounted() {
        const ctx = this.el;
        const data = {
            type: "pie",
            data: {
                labels: JSON.parse(this.el.dataset.labels),
                datasets: [{ data: JSON.parse(this.el.dataset.values) }],
            },
            options: { responsive: true, spacing: 2, offset: 2 },
        };
        this.chart = new Chart(ctx, data);
    },
    updated() {
        this.chart.data.labels = JSON.parse(this.el.dataset.labels);
        this.chart.data.datasets[0].data = JSON.parse(this.el.dataset.values);
        this.chart.update();
    },
};

Hooks.Copy = {
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

const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
    window.addEventListener(
        "phx:live_reload:attached",
        ({ detail: reloader }) => {
            // Enable server log streaming to client.
            // Disable with reloader.disableServerLogs()
            reloader.enableServerLogs();

            // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
            //
            //   * click with "c" key pressed to open at caller location
            //   * click with "d" key pressed to open at function component definition location
            let keyDown;
            window.addEventListener("keydown", (e) => (keyDown = e.key));
            window.addEventListener("keyup", (e) => (keyDown = null));
            window.addEventListener(
                "click",
                (e) => {
                    if (keyDown === "c") {
                        e.preventDefault();
                        e.stopImmediatePropagation();
                        reloader.openEditorAtCaller(e.target);
                    } else if (keyDown === "d") {
                        e.preventDefault();
                        e.stopImmediatePropagation();
                        reloader.openEditorAtDef(e.target);
                    }
                },
                true,
            );

            window.liveReloader = reloader;
        },
    );
}
