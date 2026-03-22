import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseWebRTCService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;

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
            "stun:stun1.l.google.com:19302"
          ]
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

    // 2. Karşı taraf (Ebeveyn) Odaya Girip 'Answer' yazdığında al ve uygula
    roomRef.child('answer').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['sdp'] != null) {
        var answer = RTCSessionDescription(
          data['sdp'],
          data['type'],
        );
        // Answer'ı ayarla
        final desc = await peerConnection?.getRemoteDescription();
        if (desc == null) {
          await peerConnection?.setRemoteDescription(answer);
        }
      }
    });

    // 3. Karşı Tarafın (Ebeveyn) Ağ Adreslerini (ICE Candidates) Dinle ve Ekle
    roomRef.child('calleeCandidates').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['candidate'] != null) {
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
    final roomSnapshot = await roomRef.child('offer').get();

    // Oda yoksa veya yayın başlatılmamışsa false dön
    if (!roomSnapshot.exists) {
      return false;
    }

    peerConnection = await _createPeerConnection(false);

    // 1. Bebek Telsizinin (Offer) verisini al ve Remote Description olarak ayarla
    final data = roomSnapshot.value as Map<dynamic, dynamic>;
    var offer = RTCSessionDescription(data['sdp'], data['type']);
    await peerConnection?.setRemoteDescription(offer);

    // 2. Kendi Yanıtımızı (Answer) oluştur ve Firebase'e yaz
    var answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    await roomRef.child('answer').set({
      'type': answer.type,
      'sdp': answer.sdp,
    });

    // 3. Odayı açan tarafın (Bebek) Ağ Adreslerini (ICE Candidates) Dinle ve Ekle
    roomRef.child('callerCandidates').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['candidate'] != null) {
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
}
