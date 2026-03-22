import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

  Future<void> startBabyUnit(BuildContext context) async {
    // Bebek ünitesi kamerasını başlatır ve odayı kurar
    await _webRTCService.openUserMedia(video: true, audio: true);
    localRenderer.srcObject = _webRTCService.localStream;
    
    // Rastgele 4 haneli oda kodu oluştur
    final code = (Random().nextInt(9000) + 1000).toString();
    roomId = code;
    notifyListeners(); // Hemen ekranda room code ve kamera gösterilsin.
    
    // Firebase bağlantısını arka planda yap, arayüzü kilitleme (Fire and forget)
    _webRTCService.createRoom(code).catchError((e) {
      debugPrint("Firebase Room Error: $e");
      return "";
    });
  }

  Future<void> startParentUnit(String roomCode) async {
    // Ebeveyn ünitesi
    await _webRTCService.openUserMedia(video: false, audio: true); // Push-to-talk gibi düşünüp video false yapıyoruz şimdilik
    localRenderer.srcObject = _webRTCService.localStream;
    
    roomId = roomCode;
    notifyListeners();

    _webRTCService.joinRoom(roomCode).catchError((e) {
      debugPrint("Firebase Join Room Error: $e");
      return false;
    });
  }

  Future<void> hangUp() async {
    await _webRTCService.hangUp();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    isConnected = false;
    roomId = null;
    currentRole = DeviceRole.none;
    notifyListeners();
  }

  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
