import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/web_rtc_service.dart';
import '../models/device_role.dart';
import 'dart:math';

class RoomViewModel extends ChangeNotifier {
  final FirebaseWebRTCService _webRTCService = FirebaseWebRTCService();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;


  DeviceRole currentRole = DeviceRole.none;
  String? roomId;
  
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  bool isConnected = false;
  bool isBusy = false;
  bool isReconnecting = false;

  void setBusy(bool value) {
    isBusy = value;
    notifyListeners();
  }
  
  // Odayla senkronize edilecek değerler
  bool isNightLightOn = false;
  String activeSound = '';
  double babyVolume = 1.0;
  
  StreamSubscription? _nightLightSub;
  StreamSubscription? _activeSoundSub;
  StreamSubscription? _babyVolumeSub;
  StreamSubscription? _roomAliveSub;
  StreamSubscription? _connectivitySub;

  // Ağ geçişi sırasında Firebase onDisconnect erken tetiklenir.
  // Diğer taraf false yaptığında hemen değil, grace period sonunda session bitir.
  Timer? _peerGraceTimer;
  static const int _peerGraceSeconds = 45;

  Timer? _reconnectingTimeoutTimer;
  static const int _reconnectingTimeoutSeconds = 90;

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
    if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      // Kullanıcıya reconnecting göster
      isReconnecting = true;
      isConnected = false;
      notifyListeners();

      // Reconnecting başladığında 90 saniyelik hard timeout başlat.
      // Bağlantı kurulursa iptal edilir; kurulmazsa session sonlanır.
      if (_reconnectingTimeoutTimer?.isActive != true) {
        debugPrint('Reconnecting timeout başlatıldı ($_reconnectingTimeoutSeconds sn)');
        _reconnectingTimeoutTimer = Timer(
          const Duration(seconds: _reconnectingTimeoutSeconds),
          () {
            debugPrint('Reconnecting timeout doldu → session sonlandırılıyor');
            onRoomEnded?.call();
          },
        );
      }

      // Her iki role de ICE restart başlatabilir; baby offer yazar, parent yanıtlar.
      // Parent ağ değiştiğinde de baby restart başlatmalı — ancak baby offer
      // oluşturabilir (caller), parent sadece yanıtlar. Dolayısıyla restart
      // yalnızca baby (caller) tarafından başlatılır. Parent ağ değişince
      // ICE disconnected/failed olur, baby bunu görür ve restart başlatır.
      _iceRestartDelayTimer?.cancel();
      final delaySeconds = _iceRestartAttempts == 0
          ? 2  // İlk denemede hızlı başla
          : _initialRestartDelaySeconds + (_iceRestartAttempts * 5);
      debugPrint('ICE ${state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ? "DISCONNECTED" : "FAILED"}: '
          '${delaySeconds}sn sonra restart (deneme #${_iceRestartAttempts + 1})');
      _iceRestartDelayTimer = Timer(Duration(seconds: delaySeconds), _tryIceRestart);
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _cancelSessionTimeout();
      _iceRestartAttempts = 0;
      _iceRestartDelayTimer?.cancel();
      _reconnectingTimeoutTimer?.cancel();
      _reconnectingTimeoutTimer = null;
      isReconnecting = false;
      isConnected = true;
      notifyListeners();
      debugPrint('ICE CONNECTED/COMPLETED: Bağlantı başarılı!');
    }
  }

  void _tryIceRestart() {
    if (_iceRestartAttempts >= _maxIceRestartAttempts) {
      debugPrint('ICE restart: max deneme sayısına ulaşıldı ($_maxIceRestartAttempts) → session sonlandırılıyor');
      // Tüm denemeler tükendi, artık session'ı bitir
      _startSessionTimeout();
      return;
    }
    // Sadece caller (baby) restart offer yazabilir
    if (currentRole != DeviceRole.baby) {
      debugPrint('ICE restart: parent role, baby restart bekleniyor...');
      // Parent tarafında da deneme sayısını artır, çok uzun süre sessiz kalmasın
      _iceRestartAttempts++;
      final delaySeconds = _initialRestartDelaySeconds + (_iceRestartAttempts * 5);
      _iceRestartDelayTimer = Timer(Duration(seconds: delaySeconds), _tryIceRestart);
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

  Future<String?> _waitForUid({int maxWaitMs = 5000}) async {
    const step = 200;
    int elapsed = 0;
    while (_currentUid == null && elapsed < maxWaitMs) {
      await Future.delayed(const Duration(milliseconds: step));
      elapsed += step;
    }
    return _currentUid;
  }

  Future<void> startBabyUnit(BuildContext context) async {
    try {
    final uid = await _waitForUid();
    if (uid == null) {
      throw StateError('Firebase auth could not be established. Please check your connection.');
    }

    await _webRTCService.openUserMedia(video: true, audio: true);
    localRenderer.srcObject = _webRTCService.localStream;
    
    final code = (Random().nextInt(9000) + 1000).toString();
    roomId = code;
    
    // Odayı ilk kurarken varsayılan özellikleri ve babyAlive flag'ini atomik yaz.
    // AWAIT zorunlu: dinleyiciler kurulmadan önce oda ve members kaydı
    // Firebase'de mevcut olmalı; aksi halde güvenlik kuralı okuma iznini reddeder.
    await FirebaseDatabase.instance.ref('rooms/$code').update({
      'createdBy': uid,
      'members': {uid: true},
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

    // Parent ayrıldığında baby'yi bilgilendir.
    // parentAlive yalnızca parent katıldığında yazılır; null = henüz katılmadı, false = ayrıldı.
    // Ağ geçişinde Firebase onDisconnect false yazar; grace period ile gerçek ayrılma beklenilir.
    _roomAliveSub = FirebaseDatabase.instance
        .ref('rooms/$code/parentAlive')
        .onValue
        .listen((event) {
      final val = event.snapshot.value;
      if (val == false && roomId != null) {
        // Hemen bitirme — grace period başlat
        _peerGraceTimer?.cancel();
        debugPrint('parentAlive: false → grace period başlatıldı ($_peerGraceSeconds sn)');
        _peerGraceTimer = Timer(const Duration(seconds: _peerGraceSeconds), () {
          if (roomId != null) {
            debugPrint('parentAlive grace period doldu → session sonlandırılıyor');
            onRoomEnded?.call();
          }
        });
      } else if (val == true) {
        // Parent yeniden bağlandı, grace timer'ı iptal et
        _peerGraceTimer?.cancel();
        debugPrint('parentAlive: true → parent yeniden bağlandı, grace iptal');
      }
    });

    notifyListeners();
    
    _webRTCService.createRoom(code).catchError((e) {
      debugPrint("Firebase Room Error: $e");
      return "";
    });
    } catch (_) {
      rethrow;
    }
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
    try {
    roomCode = roomCode.trim();
    final uid = await _waitForUid();
    if (uid == null) {
      return false;
    }

    final roomRef = FirebaseDatabase.instance.ref('rooms/$roomCode');

    // Register this device as a room member and signal presence before reading.
    try {
      await roomRef.child('members/$uid').set(true);
      await roomRef.child('parentAlive').set(true);
      roomRef.child('parentAlive').onDisconnect().set(false);
    } catch (_) {
      return false;
    }

    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) return false;

    await _webRTCService.openUserMedia(video: false, audio: true);
    setMicrophoneEnabled(false); 
    localRenderer.srcObject = _webRTCService.localStream;
    
    roomId = roomCode;

    // Firebase yeniden bağlandığında parentAlive: true yaz + onDisconnect yeniden kayıt et.
    // Bu sayede ağ geçişinde baby'nin grace timer'ı iptal olur.
    _connectivitySub = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected && roomId != null) {
        final aliveRef = FirebaseDatabase.instance.ref('rooms/$roomId/parentAlive');
        aliveRef.set(true);
        aliveRef.onDisconnect().set(false);
        debugPrint('Firebase bağlandı (parent): parentAlive sıfırlandı');
      }
    });

    _listenRoomData(roomCode);

    // Parent, babyAlive'ı izler; ağ geçişinde grace period bekler.
    _roomAliveSub = roomRef
        .child('babyAlive')
        .onValue
        .listen((event) {
      final val = event.snapshot.value;
      if ((val == null || val == false) && roomId != null) {
        _peerGraceTimer?.cancel();
        debugPrint('babyAlive: $val → grace period başlatıldı ($_peerGraceSeconds sn)');
        _peerGraceTimer = Timer(const Duration(seconds: _peerGraceSeconds), () {
          if (roomId != null) {
            debugPrint('babyAlive grace period doldu → session sonlandırılıyor');
            onRoomEnded?.call();
          }
        });
      } else if (val == true) {
        // Baby yeniden bağlandı
        _peerGraceTimer?.cancel();
        debugPrint('babyAlive: true → baby yeniden bağlandı, grace iptal');
      }
    });

    notifyListeners();

    _webRTCService.joinRoom(roomCode).catchError((e) {
      debugPrint("Firebase Join Room Error: $e");
      return false;
    });

    return true;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> hangUp() async {
    _cancelSessionTimeout();
    _iceRestartDelayTimer?.cancel();
    _iceRestartAttempts = 0;
    _peerGraceTimer?.cancel();
    _reconnectingTimeoutTimer?.cancel();
    _reconnectingTimeoutTimer = null;
    _nightLightSub?.cancel();
    _activeSoundSub?.cancel();
    _babyVolumeSub?.cancel();
    _roomAliveSub?.cancel();
    _connectivitySub?.cancel();

    if (roomId != null && currentRole == DeviceRole.baby) {
      // babyAlive onDisconnect'ini iptal et
      FirebaseDatabase.instance.ref('rooms/$roomId/babyAlive').onDisconnect().cancel();
      // babyAlive: false yaz → parent'ın listener'ı tetiklenir.
      // Ardından odayı sil — baby her zaman cleanup yapar.
      try {
        await FirebaseDatabase.instance.ref('rooms/$roomId/babyAlive').set(false);
      } catch (_) {}
      try {
        await FirebaseDatabase.instance.ref('rooms/$roomId').remove();
      } catch (_) {}
    }

    if (roomId != null && currentRole == DeviceRole.parent) {
      // parentAlive onDisconnect'ini iptal et, ardından false yaz → baby'nin listener'ı tetiklenir.
      // Odayı SILME — oda silinirse baby güvenlik kuralı gereği eventi alamaz.
      // Baby eventi alınca kendi hangUp()'ında odayı kaldırır.
      FirebaseDatabase.instance.ref('rooms/$roomId/parentAlive').onDisconnect().cancel();
      try {
        await FirebaseDatabase.instance.ref('rooms/$roomId/parentAlive').set(false);
      } catch (_) {}
    }
    
    await _webRTCService.hangUp();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    isReconnecting = false;
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
