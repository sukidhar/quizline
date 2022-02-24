// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
// import "../css/app.css"

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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let Hooks = {};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", (info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

Hooks.error = {
  mounted() {
    input = document.getElementById(
      "DOM-input-" + getFieldTypeFromError(this.el.id)
    );
    label = document.getElementById(
      "DOM-label-" + getFieldTypeFromError(this.el.id)
    );

    if (input && label) {
      if (this.el.classList.contains("invalid-feedback")) {
        console.log("should still show");
        if (input.classList.contains("border-gray-200")) {
          input.classList.remove("border-gray-200");
        }
        input.classList.add("border-error");
        if (label.classList.contains("text-primary-content")) {
          label.classList.remove("text-primary-content");
        }
        label.classList.add("text-error-content");
      } else if (
        this.el.classList.contains("phx-no-feedback") &&
        !this.el.classList.contains("force-error")
      ) {
        if (input.classList.contains("border-error")) {
          input.classList.remove("border-error");
        }
        input.classList.add("border-gray-200");
        if (label.classList.contains("text-error-content")) {
          label.classList.remove("text-error-content");
        }
        label.classList.add("text-primary-content");
      }
    }
  },
};

function getFieldTypeFromError(id) {
  return id.replace("DOM-error-", "");
}
