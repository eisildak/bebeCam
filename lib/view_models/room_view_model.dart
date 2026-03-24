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
  StreamSubscription? _connectivitySub;

  Timer? _sessionTimeoutTimer;
  Timer? _iceRestartDelayTimer;
  int _iceRestartAttempts = 0;
  static const int _maxIceRestartAttempts = 5;
  static const int _initialRestartDelaySeconds = 10;  // Give network time to settle
  static const int _sessionTimeoutSeconds = 120;      // Longer timeout for network transitions

  VoidCallback? onRoomEnded;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    _webRTCService.onAddRemoteStream = (stream) {
      remoteRenderer.srcObject = stream;
      isConnected = true;
      notifyListeners();
    };

    _webRTCService.onIceConnectionState = _onIceConnectionState;
  }

  void _onIceConnectionState(RTCIceConnectionState state) {
    if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      _startSessionTimeout();
      if (currentRole == DeviceRole.baby) {
        // Network might be transitioning; wait longer before restart attempt
        _iceRestartDelayTimer?.cancel();
        final delaySeconds = _initialRestartDelaySeconds + (_iceRestartAttempts * 5);
        debugPrint('ICE DISCONNECTED: ${delaySeconds}sn sonra restart denenecek');
        _iceRestartDelayTimer = Timer(Duration(seconds: delaySeconds), _tryIceRestart);
      }
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      _startSessionTimeout();
      if (currentRole == DeviceRole.baby) {
        // Failed state: try restart with exponential backoff
        _iceRestartDelayTimer?.cancel();
        final delaySeconds = _initialRestartDelaySeconds + (_iceRestartAttempts * 5);
        debugPrint('ICE FAILED: ${delaySeconds}sn sonra restart denenecek');
        _iceRestartDelayTimer = Timer(Duration(seconds: delaySeconds), _tryIceRestart);
      }
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _cancelSessionTimeout();
      _iceRestartAttempts = 0;
      _iceRestartDelayTimer?.cancel();
      debugPrint('ICE CONNECTED/COMPLETED: Bağlantı başarılı!');
    }
  }

  void _tryIceRestart() {
    if (_iceRestartAttempts >= _maxIceRestartAttempts) {
      debugPrint('ICE restart: max deneme sayısına ulaşıldı ($_maxIceRestartAttempts)');
      return;
    }
    _iceRestartAttempts++;
    debugPrint('ICE restart deneme #$_iceRestartAttempts / $_maxIceRestartAttempts');
    _webRTCService.initiateIceRestart().catchError((e) {
      debugPrint('ICE restart hatası: $e');
    });
  }

  void _startSessionTimeout() {
    if (_sessionTimeoutTimer?.isActive == true) return;
    debugPrint('Session timeout başlatıldı (${_sessionTimeoutSeconds}sn)');
    _sessionTimeoutTimer = Timer(Duration(seconds: _sessionTimeoutSeconds), () {
      debugPrint('Session timeout doldu, görüşme sonlandırılıyor');
      onRoomEnded?.call();
    });
  }

  void _cancelSessionTimeout() {
    if (_sessionTimeoutTimer?.isActive == true) {
      debugPrint('Session timeout iptal edildi (bağlantı yeniden kuruldu)');
    }
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
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
    
    // Odayı ilk kurarken varsayılan özellikleri ve babyAlive flag'ini atomik yaz
    FirebaseDatabase.instance.ref('rooms/$code').update({
      'nightLight': false,
      'activeSound': '',
      'babyVolume': 1.0,
      'babyAlive': true,
    });
    
    // Firebase bağlantısı her kurulduğunda (ilk bağlantı veya yeniden bağlanma)
    // babyAlive: true yaz ve kill detection'ı yeniden kayıt et.
    // Bu sayede kısa ağ kopuklukları (Firebase ~60sn sonra onDisconnect çalıştırır)
    // session'ı bitirmez; yeniden bağlanınca flag sıfırlanır.
    _connectivitySub = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected && roomId != null) {
        final aliveRef =
            FirebaseDatabase.instance.ref('rooms/$roomId/babyAlive');
        aliveRef.set(true);
        aliveRef.onDisconnect().set(false);
        debugPrint('Firebase bağlandı: babyAlive sıfırlandı');
      }
    });
    
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

    _listenRoomData(roomCode);

    // Yalnızca parent babyAlive'ı izler; baby kendi flag'ini izlemez.
    _roomAliveSub = FirebaseDatabase.instance
        .ref('rooms/$roomCode/babyAlive')
        .onValue
        .listen((event) {
      final val = event.snapshot.value;
      if ((val == null || val == false) && roomId != null) {
        debugPrint('babyAlive: $val → session sonlandırılıyor');
        onRoomEnded?.call();
      }
    });

    notifyListeners();

    _webRTCService.joinRoom(roomCode).catchError((e) {
      debugPrint("Firebase Join Room Error: $e");
      return false;
    });

    return true;
  }

  Future<void> hangUp() async {
    _cancelSessionTimeout();
    _iceRestartDelayTimer?.cancel();
    _iceRestartAttempts = 0;
    _nightLightSub?.cancel();
    _activeSoundSub?.cancel();
    _babyVolumeSub?.cancel();
    _roomAliveSub?.cancel();
    _connectivitySub?.cancel();

    if (roomId != null && currentRole == DeviceRole.baby) {
      // babyAlive onDisconnect'ini iptal et (process ölünce yanlışlıkla tetiklenmesin)
      FirebaseDatabase.instance.ref('rooms/$roomId/babyAlive').onDisconnect().cancel();
      // Odayı manuel olarak sil → parent, babyAlive null görünce session'ı bitirir
      await FirebaseDatabase.instance.ref('rooms/$roomId').remove();
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
    _sessionTimeoutTimer?.cancel();
    _iceRestartDelayTimer?.cancel();
    _nightLightSub?.cancel();
    _activeSoundSub?.cancel();
    _babyVolumeSub?.cancel();
    _roomAliveSub?.cancel();
    _connectivitySub?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
