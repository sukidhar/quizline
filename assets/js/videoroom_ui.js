const audioButton = document.getElementById("mic-control");
const videoButton = document.getElementById("camera-control");
const screensharingButton = document.getElementById("screensharing-control");
const leaveButton = document.getElementById("leave-control");

var localStreams;
var state = { isLocalScreenSharingOn: false };
