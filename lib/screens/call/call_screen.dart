import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/agora_service.dart';

class CallScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final String callType; // 'video' or 'audio'

  const CallScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    required this.callType,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isCameraOn = true;
  int _remoteUid = 0;
  final AgoraService _agoraService = AgoraService();
  
  late String _channelName;
  String? _token;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await _checkPermissions();
    
    // Get current user
    final currentUser = _agoraService.getCurrentUser();
    if (currentUser == null) return;
    
    // Generate channel name
    _channelName = _agoraService.generateChannelName(currentUser.uid, widget.receiverId);
    
    // Create call record
    await _agoraService.createCallRecord(
      receiverId: widget.receiverId,
      callType: widget.callType,
    );
    
    // Initialize Agora
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: AgoraService.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    
    // Register event handlers
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        setState(() {
          _isJoined = true;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        setState(() {
          _remoteUid = remoteUid;
        });
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        setState(() {
          _remoteUid = 0;
        });
        _endCall();
      },
      // Fixed: Use ErrorCodeType instead of int
      onError: (ErrorCodeType err, String msg) {
        print('Agora Error: ${err.value} - $msg');
      },
    ));
    
    // Enable video if it's a video call
    if (widget.callType == 'video') {
      await _engine.enableVideo();
      await _engine.startPreview();
    }
    
    // Join channel
    await _engine.joinChannel(
      token: _token ?? '',
      channelId: _channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _checkPermissions() async {
    if (widget.callType == 'video') {
      await [Permission.microphone, Permission.camera].request();
    } else {
      await [Permission.microphone].request();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleCamera() {
    if (widget.callType == 'video') {
      setState(() {
        _isCameraOn = !_isCameraOn;
      });
      _engine.enableLocalVideo(_isCameraOn);
    }
  }

  void _endCall() async {
    await _engine.leaveChannel();
    await _agoraService.updateCallStatus(
      channelName: _channelName,
      status: 'ended',
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _switchCamera() {
    if (widget.callType == 'video') {
      _engine.switchCamera();
    }
  }

  @override
  void dispose() {
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background color
          Container(color: Colors.black),
          
          // Remote Video View
          if (_remoteUid != 0 && widget.callType == 'video')
            Positioned.fill(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: RtcConnection(channelId: _channelName),
                ),
              ),
            ),
          
          // Local Video View (Small overlay)
          if (widget.callType == 'video' && _isJoined)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),
          
          // Call Info
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: widget.receiverImage.isNotEmpty
                      ? NetworkImage(widget.receiverImage)
                      : null,
                  child: widget.receiverImage.isEmpty
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isJoined 
                      ? (_remoteUid != 0 ? 'Connected' : 'Calling...')
                      : 'Connecting...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Call Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mute Button
                _ControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.red : Colors.green,
                  onPressed: _toggleMute,
                ),
                const SizedBox(width: 30),
                // End Call Button
                _ControlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: _endCall,
                  size: 60,
                  iconSize: 32,
                ),
                const SizedBox(width: 30),
                // Camera Toggle (only for video calls)
                if (widget.callType == 'video')
                  _ControlButton(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: _isCameraOn ? Colors.green : Colors.red,
                    onPressed: _toggleCamera,
                  ),
                // Switch Camera (only for video calls)
                if (widget.callType == 'video')
                  const SizedBox(width: 30),
                if (widget.callType == 'video')
                  _ControlButton(
                    icon: Icons.camera_front,
                    color: Colors.blue,
                    onPressed: _switchCamera,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}