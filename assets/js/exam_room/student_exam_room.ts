import { AUDIO_TRACK_CONSTRAINTS, VIDEO_TRACK_CONSTRAINTS } from "./constants";
import { Socket, Push } from "phoenix";
import {
  MembraneWebRTC,
  Peer,
  SerializedMediaEvent,
  TrackContext,
  TrackEncoding,
} from "@membraneframework/membrane-webrtc-js";

export class StudentExamRoom {
  private webrtc: MembraneWebRTC;

  private socket;
  private webrtcSocketRefs: string[] = [];
  private webrtcChannel;

  localVideoStream: MediaStream;
  localAudioStream: MediaStream;
  localVideoTrackId: string;

  constructor(userSocket: Socket, roomId: String) {
    this.socket = userSocket;
    this.webrtcChannel = this.socket.channel(`exam_room:${roomId}`);
    this.webrtcChannel.onError(() => {
      this.socketOff();
      window.location.reload();
    });
    this.webrtcChannel.onClose(() => {
      this.socketOff();
      window.location.reload();
    });

    this.webrtcSocketRefs.push(this.socket.onError(this.leave));
    this.webrtcSocketRefs.push(this.socket.onClose(this.leave));

    this.webrtc = new MembraneWebRTC({
      callbacks: {
        onSendMediaEvent: (mediaEvent: SerializedMediaEvent) => {
          this.webrtcChannel.push("mediaEvent", { data: mediaEvent });
        },
        onConnectionError: this.handleError,
        onJoinSuccess: (_peerId, peers) => {
          this.localAudioStream?.getTracks().forEach((track) => {
            this.webrtc.addTrack(track, this.localAudioStream!, {});
          });
          this.localVideoStream?.getTracks().forEach((track) => {
            this.localVideoTrackId = this.webrtc.addTrack(
              track,
              this.localVideoStream!,
              {},
              { enabled: true, active_encodings: ["m"] }
            );
          });
          console.log("hillow hillow");
        },
        onJoinError: (_metadata) => {
          console.log("error occured");

          throw `Peer denied.`;
        },
      },
    });

    this.webrtcChannel.on("mediaEvent", (event: any) =>
      this.webrtc.receiveMediaEvent(event.data)
    );
  }

  public init = async () => {
    const hasVideoInput: boolean = (
      await navigator.mediaDevices.enumerateDevices()
    ).some((device) => device.kind === "videoinput");

    if (!hasVideoInput) {
      console.log("show error message");
      return;
    }

    await navigator.mediaDevices.getUserMedia({
      video: true,
      audio: true,
    });

    const mediaDevices = await navigator.mediaDevices.enumerateDevices();
    const videoDevices = mediaDevices.filter(
      (device) => device.kind === "videoinput"
    );

    for (const device of videoDevices) {
      const constraints = {
        video: {
          ...VIDEO_TRACK_CONSTRAINTS,
          deviceId: { exact: device.deviceId },
        },
      };

      try {
        this.localVideoStream = await navigator.mediaDevices.getUserMedia(
          constraints
        );

        break;
      } catch (error) {
        console.error("Error while getting local video stream", error);
        return;
      }
    }

    try {
      this.localAudioStream = await navigator.mediaDevices.getUserMedia({
        audio: AUDIO_TRACK_CONSTRAINTS,
      });
    } catch (error) {
      console.error("Error while getting local audio stream", error);
      return;
    }

    let video = document.getElementById(
      "student-video-preview"
    ) as HTMLVideoElement;

    video.autoplay = true;
    video.playsInline = true;
    video.srcObject = this.localVideoStream;
    video.style.height = video.style.width;

    await this.phoenixChannelPushResult(this.webrtcChannel.join());
  };

  public join = () => {
    this.webrtc.join({ userType: "student", name: "test-user" });
  };

  private socketOff = () => {
    this.socket.off(this.webrtcSocketRefs);
    while (this.webrtcSocketRefs.length > 0) {
      this.webrtcSocketRefs.pop();
    }
  };

  private handleError = (message: String = "can't connect to server") => {
    console.log(message);
  };

  private leave = () => {
    this.webrtc.leave();
    this.webrtcChannel.leave();
    this.socketOff();
  };

  private phoenixChannelPushResult = async (push: Push): Promise<any> => {
    return new Promise((resolve, reject) => {
      push
        .receive("ok", (response: any) => resolve(response))
        .receive("error", (response: any) => reject(response));
    });
  };
}
