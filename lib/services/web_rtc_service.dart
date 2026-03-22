import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseWebRTCService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  bool _isRestarting = false;

  Function(MediaStream stream)? onAddRemoteStream;

  Future<void> openUserMedia({required bool video, required bool audio}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video ? {
        'facingMode': 'user',
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
      } : false,
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<RTCPeerConnection> _createPeerConnection(bool isCaller) async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {
          "urls": [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302",
          ]
        },
        {
          "urls": [
            "turn:openrelay.metered.ca:80",
            "turn:openrelay.metered.ca:443",
            "turn:openrelay.metered.ca:443?transport=tcp"
          ],
          "username": "openrelayproject",
          "credential": "openrelayproject"
        }
      ]
    };

    final pc = await createPeerConnection(configuration);

    // Kendi IP/Ağ bilgilerimizi bulduğumuzda Firebase'e yazıyoruz
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (roomId != null) {
        String collection = isCaller ? 'callerCandidates' : 'calleeCandidates';
        _db.ref('rooms/$roomId/$collection').push().set(candidate.toMap());
      }
    };

    // Karşı taraftan Görüntü/Ses geldiğinde UI'ı tetikliyoruz
    pc.onAddStream = (MediaStream stream) {
      debugPrint("Görüntü/Ses stream'i eklendi!");
      remoteStream = stream;
      onAddRemoteStream?.call(remoteStream!);
    };
    
    pc.onTrack = (RTCTrackEvent event) {
      debugPrint("Track alındı: ${event.track.kind}");
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        onAddRemoteStream?.call(remoteStream!);
      }
    };

    // Bizim Kameramızı/Mikrofonumuzu WebRTC'ye ekliyoruz
    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        pc.addTrack(track, localStream!);
      });
    }

    return pc;
  }

  Future<String> createRoom(String room) async {
    roomId = room;
    final roomRef = _db.ref('rooms/$roomId');
    // Odada önceden kalıntı veri varsa temizle
    await roomRef.remove();

    peerConnection = await _createPeerConnection(true);

    // 1. Offer oluştur ve Firebase'e yaz
    RTCSessionDescription offer = await peerConnection!.createOffer();
    
    // LocalDescription ayarlandıktan sonra ICE adayları toplanır, bu yüzden hemen sonrasında veya öncesinde db yazılır.
    // 'set' kullanmak tüm 'rooms/$roomId' dizinini ezer; eğer ICE adayları toplanmaya başlandıysa
    // 'callerCandidates' alanı silinmiş olur. Bu yüzden '.child('offer').set' kullanıyoruz.
    await roomRef.child('offer').set({
      'type': offer.type,
      'sdp': offer.sdp,
    });

    await peerConnection!.setLocalDescription(offer);

    // 2. Karşı taraf (Ebeveyn) Odaya Girip 'Answer' yazdığında veya ICE Restart olduğunda al ve uygula
    roomRef.child('answer').onValue.listen((event) async {
      debugPrint("Firebase Listener: 'answer' triggered. Value exists: ${event.snapshot.value != null}");
      if (event.snapshot.value == null) return;
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (data['sdp'] != null) {
        if (peerConnection?.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          try {
            var answer = RTCSessionDescription(data['sdp'], data['type']);
            await peerConnection?.setRemoteDescription(answer);
          } catch (e) {
            debugPrint("Error setting remote answer: $e");
          }
        }
      } catch (e) {
        debugPrint("Error parsing answer data: $e");
      }
    });

    // Otomatik Yeniden Bağlanma (ICE Restart) Taleplerini Dinle
    roomRef.child('requestRestart').onValue.listen((event) async {
      if (event.snapshot.value != null) {
        debugPrint("Parent requested ICE Restart. Re-negotiating...");
        _performIceRestart(roomRef);
      }
    });

    // İnternet kopmasını/değişmesini kendin tespit edersen yeniden başlat
    peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint("Baby Unit lost connection. Initiating Auto-Reconnect.");
        _performIceRestart(roomRef);
      }
    };

    // 3. Karşı Tarafın (Ebeveyn) Ağ Adreslerini (ICE Candidates) Dinle ve Ekle
    roomRef.child('calleeCandidates').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (data['candidate'] != null) {
        peerConnection?.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      }
    });

    return roomId!;
  }

  Future<bool> joinRoom(String room) async {
    roomId = room;
    final roomRef = _db.ref('rooms/$roomId');

    peerConnection = await _createPeerConnection(false);

    // 1 & 2. Bebek Telsizinin (Offer) verisini dinamik olarak dinle (İlk bağlantı ve ICE Restart'lar dahil)
    roomRef.child('offer').onValue.listen((event) async {
      debugPrint("Firebase Listener: 'offer' triggered. Value exists: ${event.snapshot.value != null}");
      if (event.snapshot.value == null) return;
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (data['sdp'] != null) {
          debugPrint("SignalingState: ${peerConnection?.signalingState}");
        if (peerConnection?.signalingState == RTCSignalingState.RTCSignalingStateStable) {
          debugPrint("Received new Offer, generating Answer...");
          try {
            var offer = RTCSessionDescription(data['sdp'], data['type']);
            await peerConnection?.setRemoteDescription(offer);
            
            var answer = await peerConnection!.createAnswer();
            await peerConnection!.setLocalDescription(answer);
            
            await roomRef.child('answer').set({
              'type': answer.type,
              'sdp': answer.sdp,
            });
          } catch (e) {
            debugPrint("Error responding to offer: $e");
          }
        }
      } catch (e) {
        debugPrint("Error parsing offer data: $e");
      }
    });

    // Ebeveyn bağlantısının koptuğunu saptarsa Bebek'ten ICE Restart talep et
    peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint("Parent Unit lost connection. Requesting Auto-Reconnect from Baby.");
        roomRef.child('requestRestart').set(DateTime.now().millisecondsSinceEpoch);
      }
    };

    // 3. Odayı açan tarafın (Bebek) Ağ Adreslerini (ICE Candidates) Dinle ve Ekle
    roomRef.child('callerCandidates').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (data['candidate'] != null) {
        peerConnection?.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      }
    });
    
    return true;
  }

  Future<void> hangUp() async {
    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    remoteStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.dispose();
    peerConnection?.close();
    
    if (roomId != null) {
      await _db.ref('rooms/$roomId').remove();
    }
  }

  Future<void> _performIceRestart(DatabaseReference roomRef) async {
    if (peerConnection == null || _isRestarting) return;
    _isRestarting = true;
    try {
      RTCSessionDescription offer = await peerConnection!.createOffer({'iceRestart': true});
      await peerConnection!.setLocalDescription(offer);
      await roomRef.child('offer').set({'type': offer.type, 'sdp': offer.sdp});
    } catch (e) {
      debugPrint("ICE Restart Error: $e");
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        _isRestarting = false;
      });
    }
  }
}
