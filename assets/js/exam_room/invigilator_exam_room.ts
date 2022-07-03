import { AUDIO_TRACK_CONSTRAINTS, MediaStreams } from "./constants";
import { Push, Socket } from "phoenix";
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
  localAudioStream: MediaStream;
  private peers: Peer[] = [];
  public tracks: Map<string, TrackContext[]> = new Map();
  private hookRef: any;

  user = {};

  constructor(hookRef: any) {
    this.hookRef = hookRef;

    this.webrtc = new MembraneWebRTC({
      callbacks: {
        onSendMediaEvent: (mediaEvent: SerializedMediaEvent) => {
          this.webrtcChannel.push("mediaEvent", { data: mediaEvent });
        },
        onConnectionError: this.handleError,
        onJoinSuccess: (_peerId, peers) => {
          hookRef.pushEvent(
            "joined-rtc-engine",
            { peers: peers },
            (reply, ref) => {}
          );
          this.localAudioStream
            ?.getTracks()
            .forEach((track) =>
              this.webrtc.addTrack(track, this.localAudioStream!, {})
            );
          peers.forEach((peer) => {
            this.tracks.set(peer.id, []);
          });
        },
        onJoinError: (_metadata) => {
          throw `Peer denied.`;
        },
        onTrackReady: (ctx) => {
          this.tracks.get(ctx.peer.id)?.push(ctx);

          hookRef.pushEvent(
            "track-ready",
            {
              peer: ctx.peer,
              trackId: ctx.trackId,
            },
            (reply, ref) => {}
          );
        },
        onTrackAdded: (_ctx) => {},
        onTrackRemoved: (ctx) => {
          let newPeerTracks = this.tracks
            .get(ctx.peer.id)
            ?.filter((track) => track.trackId !== ctx.trackId)!;
          this.tracks.set(ctx.peer.id, newPeerTracks);
        },
        onPeerJoined: (peer) => {
          this.tracks.set(peer.id, []);
          hookRef.pushEvent("peer-joined", { peer: peer }, (reply, ref) => {});
        },
        onPeerLeft: (peer) => {
          this.tracks.delete(peer.id);
          hookRef.pushEvent("peer-left", { peer: peer }, (reply, ref) => {});
        },
        onPeerUpdated: (_ctx) => {},
      },
    });
  }

  public async joinChannel(socket: Socket, roomId: string, user) {
    this.socket = socket;
    this.webrtcChannel = this.socket.channel(`exam_room:${roomId}`, {
      user: user,
    });
    this.user = user;
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

    this.webrtcChannel.on("mediaEvent", (event: any) =>
      this.webrtc.receiveMediaEvent(event.data)
    );

    await this.phoenixChannelPushResult(this.webrtcChannel.join());
    this.joinRTCEngine();
  }

  public joinRTCEngine() {
    this.webrtc.join(this.user);
  }

  public init = async () => {
    await navigator.mediaDevices.getUserMedia({
      audio: true,
      video: false,
    });

    try {
      this.localAudioStream = await navigator.mediaDevices.getUserMedia({
        audio: AUDIO_TRACK_CONSTRAINTS,
      });
      this.localAudioStream?.getTracks().forEach((track) => {
        track.enabled = false;
      });
    } catch (error) {
      Promise.reject({
        error: error,
        device: "microphone",
      });
    }
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

  private phoenixChannelPushResult = async (push: Push): Promise<any> => {
    return new Promise((resolve, reject) => {
      push
        .receive("ok", (response: any) => resolve(response))
        .receive("error", (response: any) => reject(response));
    });
  };

  private addNewVideoElement = (peer: Peer) => {
    let div = document.createElement("div");
    div.className = "remote-video-element";
    let videoElement = document.createElement("video") as HTMLVideoElement;
    videoElement.id = `${peer.id}-video-element`;
    videoElement.autoplay = true;
    videoElement.playsInline = true;
    videoElement.muted = false;

    let container = document.getElementById("streams-container");
    div.appendChild(videoElement);
    container.appendChild(div);
  };

  private attachStream = (peerId: string, streams: MediaStream) => {
    const videoId = `${peerId}-video-element`;

    let video = document.getElementById(videoId) as HTMLVideoElement;

    video.srcObject = streams;
  };

  private removeVideoElement = (peer: Peer) => {
    const videoId = `${peer.id}-video-element`;

    let video = document.getElementById(videoId) as HTMLVideoElement;
    document.removeChild(video.parentNode);
  };
}
