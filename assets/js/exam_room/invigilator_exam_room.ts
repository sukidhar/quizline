import { AUDIO_TRACK_CONSTRAINTS, VIDEO_TRACK_CONSTRAINTS } from "./constants";
import { Socket } from "phoenix";
import {
  MembraneWebRTC,
  Peer,
  SerializedMediaEvent,
  TrackContext,
  TrackEncoding,
} from "@membraneframework/membrane-webrtc-js";

export class InvigilatorExamRoom {
  private webrtc;
  private socket: Socket;
  private webrtcSocketRefs: string[] = [];
  private webrtcChannel;

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
          console.log(peers);
        },
      },
    });
    this.webrtcChannel.on("mediaEvent", (event: any) =>
      this.webrtc.receiveMediaEvent(event.data)
    );
  }

  public init = async () => {
    await this.webrtcChannel.join();
    this.webrtc.join({ userType: "invigilator" });
  };

  private socketOff = () => {
    this.socket.off(this.webrtcSocketRefs);
    while (this.webrtcSocketRefs.length > 0) {
      this.webrtcSocketRefs.pop();
    }
  };

  private leave = () => {
    this.webrtc.leave();
    this.webrtcChannel.leave();
    this.socketOff();
  };

  private handleError = (message: String = "can't connect to server") => {
    console.log(message);
  };
}
