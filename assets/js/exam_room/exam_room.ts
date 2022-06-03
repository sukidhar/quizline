import { Socket } from "phoenix";
import {
  MembraneWebRTC,
  Peer,
  SerializedMediaEvent,
  TrackContext,
  TrackEncoding,
} from "@membraneframework/membrane-webrtc-js";

export enum UserType {
  student,
  invigilator,
}

export class Room {
  private webrtc: MembraneWebRTC;

  private socket;
  private webrtcSocketRefs: string[] = [];
  private webrtcChannel;

  private userType: UserType;

  constructor(userSocket: Socket, roomId: String, userType: UserType) {
    this.userType = userType;
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

    this.webrtc = new MembraneWebRTC({
      callbacks: {
        onSendMediaEvent: (mediaEvent: SerializedMediaEvent) => {
          this.webrtcChannel.push("mediaEvent", { data: mediaEvent });
        },
      },
    });
  }

  public init = async () => {
    const hasVideoInput: boolean = (
      await navigator.mediaDevices.enumerateDevices()
    ).some((device) => device.kind === "videoinput");

    //ask for perms
    await navigator.mediaDevices.getUserMedia({
      audio: true,
      video: hasVideoInput,
    });

    // Refresh mediaDevices list after ensuring permissions are granted
    // Before that, enumerateDevices() call would not return deviceIds
    const mediaDevices = await navigator.mediaDevices.enumerateDevices();
    console.log(mediaDevices);

    await this.webrtcChannel.join();
  };

  private socketOff = () => {
    this.socket.off(this.webrtcSocketRefs);
    while (this.webrtcSocketRefs.length > 0) {
      this.webrtcSocketRefs.pop();
    }
  };
}
