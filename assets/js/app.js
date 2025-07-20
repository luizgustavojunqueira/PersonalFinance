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
import * as echarts from "echarts";
import topbar from "../vendor/topbar";

let Hooks = {};

Hooks.Modal = {
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

Hooks.ToggleSidebar = {
    mounted() {
        const sidebar = document.getElementById("sidebar");

        this.el.addEventListener("click", () => {
            sidebar.classList.toggle("expanded");
        });
    },
};

Hooks.Chart = {
    mounted() {
        selector = "#" + this.el.id;
        this.chart = echarts.init(this.el.querySelector(selector + "-chart"));
        option = JSON.parse(
            this.el.querySelector(selector + "-data").textContent,
        );
        this._updateChartOptions();
        window.addEventListener("resize", () => {
            this.chart.resize();
        });
    },

    updated() {
        this._updateChartOptions();
    },

    _updateChartOptions() {
        selector = "#" + this.el.id;
        option = JSON.parse(
            this.el.querySelector(selector + "-data").textContent,
        );

        const restanteSeries = option.series.find((s) => s.name === "Restante");
        if (restanteSeries && restanteSeries.label) {
            restanteSeries.label.formatter = function (params) {
                return params.name === "Sem Categoria"
                    ? ""
                    : "R$" + params.value;
            };
        }

        const metaSeries = option.series.find((s) => s.name === "Meta");
        if (metaSeries && metaSeries.label) {
            metaSeries.label.formatter = function (params) {
                return params.name === "Sem Categoria"
                    ? ""
                    : "R$" + params.value;
            };
        }

        this.chart.setOption(option);
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

Hooks.ColorPicker = {
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
