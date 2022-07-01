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
import userSocket from "./user_socket";
import { StudentExamRoom } from "./exam_room/student_exam_room";
import { InvigilatorExamRoom } from "./exam_room/invigilator_exam_room";
// import picker from "./calender";

let Hooks = {};
let Uploaders = {};
Uploaders.S3 = (entries, onViewError) => {
  entries.forEach((entry) => {
    let formData = new FormData();
    let { url, fields } = entry.meta;
    Object.entries(fields).forEach(([key, val]) => {
      console.log(key, val);
      formData.append(key, val);
    });
    formData.append("file", entry.file);
    let xhr = new XMLHttpRequest();
    onViewError(() => xhr.abort());
    xhr.onload = () => {
      xhr.status === 204 ? entry.progress(100) : entry.error();
    };
    xhr.onerror = () => {
      entry.error();
    };
    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100);
        if (percent < 100) {
          entry.progress(percent);
        }
      }
    });
    xhr.open("POST", url, true);
    xhr.send(formData);
  });
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  uploaders: Uploaders,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", (info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();
// liveSocket.enableDebug();
// expose liveSocket on window for web console debug logs and latency simulation:
liveSocket.enableDebug();
// liveSocket.enableLatencySim(500); // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

Hooks.error = {
  mounted() {
    console.log("called by" + this.el.id);
    input = document.getElementById(
      "DOM-input-" + getFieldTypeFromError(this.el.id)
    );
    label = document.getElementById(
      "DOM-label-" + getFieldTypeFromError(this.el.id)
    );

    if (input && label) {
      if (this.el.classList.contains("phx-no-feedback")) {
        if (input.classList.contains("border-error")) {
          input.classList.remove("border-error");
        }
        input.classList.add("border-gray-200");
        if (label.classList.contains("text-error-content")) {
          label.classList.remove("text-error-content");
        }
        label.classList.add("text-primary-content");
      } else if (this.el.classList.contains("invalid-feedback")) {
        if (input.classList.contains("border-gray-200")) {
          input.classList.remove("border-gray-200");
        }
        input.classList.add("border-error");
        if (label.classList.contains("text-primary-content")) {
          label.classList.remove("text-primary-content");
        }
        label.classList.add("text-error-content");
      }
    }
  },
  updated() {
    console.log(this.el);
  },
};

Hooks.scrollTracker = {
  mounted() {
    this.el.addEventListener("scroll", (event) => {
      console.log(this.el.scrollTop);
      console.log(this.el.clientHeight);
    });
  },
};

Hooks.scrollLock = {
  mounted() {
    this.parent = this.el.parentElement;
    this.parent.classList.add("no-scroll");
  },
  destroyed() {
    this.parent.classList.remove("no-scroll");
  },
};

Hooks.date_button = {
  mounted() {
    this.el.addEventListener("click", () => {
      let input_el = document.getElementById(this.el.dataset.valueField);
      input_el.value = this.el.dataset.valueDate;
      input_el.dispatchEvent(new Event("input", { bubbles: true }));
    });
  },
};

Hooks.searchBar = {
  mounted() {
    this.el.oninput = () => {
      this.pushEvent(
        "search-field-changed",
        {
          filter: this.el.value,
          event: this.el.dataset.event,
        },
        (reply, ref) => {
          console.log(reply);
        }
      );
    };
  },
};
Hooks.DepartmentButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      let input_el = document.getElementById("department-input-field");
      switch (this.el.dataset.event || "") {
        case "select":
          this.pushEvent("select-department", this.el.dataset, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        case "deselect":
          this.pushEvent("deselect-department", null, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        default:
          break;
      }
    });
  },
};

Hooks.SemesterButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      let input_el = document.getElementById("semester-input-field");
      switch (this.el.dataset.event || "") {
        case "select":
          this.pushEvent("select-semester", this.el.dataset, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        case "deselect":
          this.pushEvent("deselect-semester", null, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        default:
          break;
      }
    });
  },
};

Hooks.SelectButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      let type = (this.el.dataset.type || "").toLowerCase();
      let input_el = document.getElementById(`${type}-input-field`);
      switch (this.el.dataset.event || "") {
        case "select":
          this.pushEvent(`select-${type}`, this.el.dataset, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        case "deselect":
          this.pushEvent(`deselect-${type}`, null, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        default:
          break;
      }
    });
  },
};

Hooks.subjectPressed = {
  mounted() {
    this.el.addEventListener("click", () => {
      var input_el = document.getElementById("subject-input-field");
      switch (this.el.dataset.event || "") {
        case "select":
          this.pushEvent("select-subject", this.el.dataset, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        case "deselect":
          this.pushEvent("deselect-subject", null, (reply, ref) => {
            input_el.dispatchEvent(new Event("input", { bubbles: true }));
          });
          break;
        default:
          break;
      }
    });
  },
};
let room = null;
// Hooks.ExamRoomStudent = {
//   async mounted() {
//     room = new StudentExamRoom();
//     await room.init();
//     this.handleEvent("start-exam-room", (data) => {
//       console.log(data);
//     });
//   },
// };

Hooks.StudentStartUpPreview = {
  mounted() {
    room = new StudentExamRoom(userSocket, this.el.dataset.room_id);
    room
      .init("student-video-preview")
      .then((_) => {
        this.pushEvent("video-stream-started", {});
        this.handleEvent("join-exam-channel", (data) => {
          let { room_id, user } = data;
          room.joinChannel(userSocket, room_id, { ...user, type: "student" });
        });
      })
      .catch((error) => {
        this.pushEvent("frontend-error", { error: error.message });
      });
  },
};

Hooks.VideoStreamButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      if (room) {
        room.setVideoStreamState(this.el.dataset.video === "true");
      }
    });
  },
};

Hooks.AudioStreamButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      if (room) {
        room.setAudioStreamState(this.el.dataset.audio === "true");
      }
    });
  },
};

Hooks.InvigilatorRoomStartUp = {
  mounted() {
    room = new InvigilatorExamRoom(this);
    room
      .init()
      .then((_) => {
        this.pushEvent("started-room");
        this.handleEvent("join-exam-channel", (data) => {
          let { room_id, user } = data;
          room.joinChannel(userSocket, room_id, {
            ...user,
            type: "invigilator",
          });
        });
      })
      .catch((err) => {
        console.log(err);
      });
  },
};

Hooks.InvigilatorRoomView = {
  mounted() {
    // room = new InvigilatorExamRoom(
    //   userSocket,
    //   this.el.dataset.room_id || "hello",
    //   this
    // );
    // room.init();
    // this.handleEvent("set-track", (data) => {
    //   let video = document.getElementById(`${data.peer.id}-video-element`);
    //   if (video) {
    //     room.tracks.get(data.peer.id).forEach((ctx) => {
    //       if (video.srcObject != ctx.stream) {
    //         video.srcObject = ctx.stream;
    //       }
    //     });
    //   }
    // });
  },
};

Hooks.Timezone = {
  mounted() {
    console.log("hello");
    let localTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    this.pushEvent("timezone-callback", { timezone: localTz });
  },
};

Hooks.DocumentViewer = {
  mounted() {
    request = JSON.parse(this.el.dataset.request);
    let xhr = new XMLHttpRequest();
    el = this.el;
    xhr.responseType = "blob";
    xhr.open("GET", request.url);
    console.log(request);
    Object.entries(request.headers).forEach((entry) => {
      let [key, value] = entry;
      xhr.setRequestHeader(key, value);
    });
    xhr.onreadystatechange = xhr.onreadystatechange = function () {
      // In local files, status is 0 upon success in Mozilla Firefox
      if (xhr.readyState === XMLHttpRequest.DONE) {
        var status = xhr.status;
        if (status === 0 || (status >= 200 && status < 400)) {
          // The request has been completed successfully
          let url = URL.createObjectURL(xhr.response);
          el.src = `${url}#toolbar=0&navpanes=0&scrollbar=0`;
          //? add customisation for firefox
        } else {
          //! Oh no! There has been an error with the request!
        }
      }
    };
    xhr.send();
  },
};

Hooks.SessionError = {
  refreshInterval: null,
  mounted() {
    let p = document.getElementById("error-text");
    let count = 15;
    this.refreshInterval = setInterval(() => {
      count -= 1;
      if (count == 0) {
        document.location.replace("https://google.com");
      }
      if (p) {
        p.innerText = `There is a session running already on other device or browser. Please close the previous session to continue using this new session, This tab will close itself in ${count} seconds if not closed.`;
      }
    }, 1000);
  },
  destroyed() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
  },
};

function getFieldTypeFromError(id) {
  return id.replace("DOM-error-", "");
}
