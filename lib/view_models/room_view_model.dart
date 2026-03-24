import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/web_rtc_service.dart';
import '../models/device_role.dart';
import 'dart:math';

class RoomViewModel extends ChangeNotifier {
  final FirebaseWebRTCService _webRTCService = FirebaseWebRTCService();
  
  DeviceRole currentRole = DeviceRole.none;
  String? roomId;
  
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  bool isConnected = false;
  
  // Odayla senkronize edilecek değerler
  bool isNightLightOn = false;
  String activeSound = '';
  double babyVolume = 1.0;
  
  StreamSubscription? _nightLightSub;
  StreamSubscription? _activeSoundSub;
  StreamSubscription? _babyVolumeSub;
  StreamSubscription? _roomAliveSub;

  VoidCallback? onRoomEnded;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    
    _webRTCService.onAddRemoteStream = (stream) {
      remoteRenderer.srcObject = stream;
      isConnected = true;
      notifyListeners();
    };
  }

  void selectRole(DeviceRole role) {
    currentRole = role;
    notifyListeners();
  }
  
  void _listenRoomData(String code) {
    var ref = FirebaseDatabase.instance.ref('rooms/$code');
    _nightLightSub = ref.child('nightLight').onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is bool) {
        isNightLightOn = event.snapshot.value as bool;
        notifyListeners();
      }
    });
    _activeSoundSub = ref.child('activeSound').onValue.listen((event) {
      if (event.snapshot.value != null) {
        activeSound = event.snapshot.value as String;
        notifyListeners();
      }
    });
    _babyVolumeSub = ref.child('babyVolume').onValue.listen((event) {
      if (event.snapshot.value != null) {
        babyVolume = (event.snapshot.value as num).toDouble();
        notifyListeners();
      }
    });
    _roomAliveSub = ref.onValue.listen((event) {
      if (event.snapshot.value == null) {
        // The room was deleted in Firebase, meaning the session ended
        if (roomId != null) {
          onRoomEnded?.call();
        }
      }
    });
  }

  void toggleNightLight(bool enabled) {
    if (roomId != null) {
      FirebaseDatabase.instance.ref('rooms/$roomId/nightLight').set(enabled);
    }
  }

  void setActiveSound(String soundType) {
    if (roomId != null) {
      FirebaseDatabase.instance.ref('rooms/$roomId/activeSound').set(soundType);
    }
  }

  void setBabyVolume(double vol) {
    if (roomId != null) {
      FirebaseDatabase.instance.ref('rooms/$roomId/babyVolume').set(vol);
    }
  }

  Future<void> startBabyUnit(BuildContext context) async {
    await _webRTCService.openUserMedia(video: true, audio: true);
    localRenderer.srcObject = _webRTCService.localStream;
    
    final code = (Random().nextInt(9000) + 1000).toString();
    roomId = code;
    
    // Odayı ilk kurarken varsayılan özellikleri yolla
    FirebaseDatabase.instance.ref('rooms/$code').update({
      'nightLight': false,
      'activeSound': '',
      'babyVolume': 1.0,
    });
    
    // Uygulama aniden kapanırsa (kill edilirse) odayı sil
    FirebaseDatabase.instance.ref('rooms/$code').onDisconnect().remove();
    
    _listenRoomData(code);
    notifyListeners();
    
    _webRTCService.createRoom(code).catchError((e) {
      debugPrint("Firebase Room Error: $e");
      return "";
    });
  }

  void setMicrophoneEnabled(bool enabled) {
    if (_webRTCService.localStream != null) {
      final audioTracks = _webRTCService.localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        audioTracks[0].enabled = enabled;
      }
    }
  }

  void setRemoteAudioEnabled(bool enabled) {
    if (remoteRenderer.srcObject != null) {
      final audioTracks = remoteRenderer.srcObject!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = enabled;
      }
    }
  }

  Future<bool> startParentUnit(String roomCode) async {
    roomCode = roomCode.trim();
    final roomSnapshot = await FirebaseDatabase.instance.ref('rooms/$roomCode').get();
    if (!roomSnapshot.exists) return false;

    await _webRTCService.openUserMedia(video: false, audio: true);
    setMicrophoneEnabled(false); 
    localRenderer.srcObject = _webRTCService.localStream;
    
    roomId = roomCode;
    
    // Uygulama aniden kapanırsa (kill edilirse) odayı sil
    FirebaseDatabase.instance.ref('rooms/$roomCode').onDisconnect().remove();
    
    _listenRoomData(roomCode);
    notifyListeners();

    _webRTCService.joinRoom(roomCode).catchError((e) {
      debugPrint("Firebase Join Room Error: $e");
      return false;
    });

    return true;
  }

  Future<void> hangUp() async {
    _nightLightSub?.cancel();
    _activeSoundSub?.cancel();
    _babyVolumeSub?.cancel();
    _roomAliveSub?.cancel();
    
    if (roomId != null) {
      FirebaseDatabase.instance.ref('rooms/$roomId').onDisconnect().cancel();
    }
    
    await _webRTCService.hangUp();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    isConnected = false;
    roomId = null;
    isNightLightOn = false;
    activeSound = '';
    babyVolume = 1.0;
    currentRole = DeviceRole.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _nightLightSub?.cancel();
    _activeSoundSub?.cancel();
    _babyVolumeSub?.cancel();
    _roomAliveSub?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
