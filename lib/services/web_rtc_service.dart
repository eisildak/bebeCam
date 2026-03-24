import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseWebRTCService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Xirsys — görüşme başında fresh credentials çekilir
  static const _xirsysUrl = 'https://global.xirsys.net/_turn/bebeCam';
  static const _xirsysAuth = 'erolis:29cc112c-27b7-11f1-b913-0242ac130002';
  static const _cacheKey = 'xirsys_ice_cache_v2';      // v2: her URL ayrı entry
  static const _cacheTimeKey = 'xirsys_ice_cache_time_v2';
  // Xirsys token'ı 24 saat geçerli; 23 saatte bir yenile
  static const _cacheDurationMs = 23 * 60 * 60 * 1000;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;

  bool _isCaller = false;
  bool _isRestartingIce = false;

  // Aynı offer/answer'ın iki kez işlenmesini önlemek için
  String? _lastProcessedOfferId;
  String? _lastProcessedAnswerId;

  StreamSubscription? _answerSub;
  StreamSubscription? _offerSub;
  StreamSubscription? _callerCandidatesSub;
  StreamSubscription? _calleeCandidatesSub;

  Function(MediaStream stream)? onAddRemoteStream;

  /// ICE bağlantı durumu değiştiğinde ViewModel'i bilgilendirir
  Function(RTCIceConnectionState)? onIceConnectionState;

  Future<void> openUserMedia({required bool video, required bool audio}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'facingMode': 'user',
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
            }
          : false,
    };
    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  /// Xirsys TURN credentials — 23 saatlik önbellekle, ilk görüşme sonrası gecikme yok.
  Future<List<Map<String, dynamic>>> _fetchIceServers() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
    final cacheStr = prefs.getString(_cacheKey);
    final age = DateTime.now().millisecondsSinceEpoch - cacheTime;

    if (cacheStr != null && age < _cacheDurationMs) {
      debugPrint('Xirsys: önbellek kullanılıyor (${(age / 3600000).toStringAsFixed(1)}h önce alındı)');
      return (jsonDecode(cacheStr) as List).cast<Map<String, dynamic>>();
    }

    try {
      final client = HttpClient();
      final request = await client.putUrl(Uri.parse(_xirsysUrl));
      final encoded = base64Encode(utf8.encode(_xirsysAuth));
      request.headers.set(HttpHeaders.authorizationHeader, 'Basic $encoded');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write('{"format": "urls"}');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final ice = data['v']['iceServers'] as Map<String, dynamic>;
      final urls = (ice['urls'] as List).cast<String>();
      final username = ice['username'] as String;
      final credential = ice['credential'] as String;

      // flutter_webrtc native katmanı 'urls' için tek string bekler.
      // Array geçilirse TURN ignore edilip yalnızca STUN çalışır.
      // Her URL'i ayrı entry olarak ekliyoruz.
      final result = urls
          .map((url) => <String, dynamic>{
                'urls': url,
                'username': username,
                'credential': credential,
              })
          .toList();

      await prefs.setString(_cacheKey, jsonEncode(result));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('Xirsys: taze credentials alındı ve önbelleğe kaydedildi');
      return result;
    } catch (e) {
      // Hata durumunda — süresi dolmuş önbellek varsa yine de kullan
      if (cacheStr != null) {
        debugPrint('Xirsys fetch hatası: $e — süresi dolmuş önbellek kullanılıyor');
        return (jsonDecode(cacheStr) as List).cast<Map<String, dynamic>>();
      }
      debugPrint('Xirsys fetch hatası: $e — yalnızca STUN kullanılacak');
      return [];
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(
    bool isCaller,
    List<Map<String, dynamic>> turnServers,
  ) async {
    // NOT: Farklı ağlar arası bağlantı (WiFi ↔ Mobil veri) için
    // TURN sunucusu zorunludur. STUN tek başına Symmetric NAT'ı aşamaz.
    // Kendi TURN sunucunuzu aşağıya ekleyin (örn. coturn, Xirsys, metered.ca):
    //
    // {
    //   "urls": "turn:your-turn-server.com:3478",
    //   "username": "kullanici",
    //   "credential": "sifre",
    // },
    // {
    //   "urls": "turns:your-turn-server.com:5349",
    //   "username": "kullanici",
    //   "credential": "sifre",
    // },
    final configuration = {
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
        ...turnServers,
      ]
    };

    final pc = await createPeerConnection(configuration);

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (roomId != null) {
        final collection = isCaller ? 'callerCandidates' : 'calleeCandidates';
        _db.ref('rooms/$roomId/$collection').push().set(candidate.toMap());
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('ICE state: $state');
      onIceConnectionState?.call(state);
    };

    pc.onAddStream = (MediaStream stream) {
      debugPrint('Stream eklendi!');
      remoteStream = stream;
      onAddRemoteStream?.call(remoteStream!);
    };

    pc.onTrack = (RTCTrackEvent event) {
      debugPrint('Track alındı: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        onAddRemoteStream?.call(remoteStream!);
      }
    };

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        pc.addTrack(track, localStream!);
      }
    }

    return pc;
  }

  // ───────────────────────────── BABY UNIT (Caller) ─────────────────────────

  Future<String> createRoom(String room) async {
    _isCaller = true;
    _lastProcessedAnswerId = null;
    roomId = room;
    final roomRef = _db.ref('rooms/$roomId');

    // Eski WebRTC verilerini temizle
    await roomRef.child('offer').remove();
    await roomRef.child('answer').remove();
    await roomRef.child('callerCandidates').remove();
    await roomRef.child('calleeCandidates').remove();

    final turnServers = await _fetchIceServers();
    peerConnection = await _createPeerConnection(true, turnServers);

    // 1. Offer oluştur ve Firebase'e yaz
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    final offerId = DateTime.now().millisecondsSinceEpoch.toString();
    await roomRef.child('offer').set({
      'type': offer.type,
      'sdp': offer.sdp,
      'id': offerId,
    });

    // 2. Answer geldiğinde işle (ilk bağlantı + ICE restart yanıtı)
    _answerSub = roomRef.child('answer').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null || data['sdp'] == null) return;

      final answerId = data['id'] as String?;
      if (answerId != null && answerId == _lastProcessedAnswerId) return;
      _lastProcessedAnswerId = answerId;

      final answer = RTCSessionDescription(data['sdp'], data['type']);
      await peerConnection?.setRemoteDescription(answer);
      debugPrint('Answer işlendi (id: $answerId)');
    });

    // 3. Callee ICE candidates - use onValue to handle list refreshes
    _calleeCandidatesSub =
        roomRef.child('calleeCandidates').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        for (final entry in data.entries) {
          final candidate = entry.value as Map<dynamic, dynamic>?;
          if (candidate != null && candidate['candidate'] != null) {
            peerConnection?.addCandidate(
              RTCIceCandidate(
                candidate['candidate'],
                candidate['sdpMid'],
                candidate['sdpMLineIndex']
              ),
            );
          }
        }
      }
    });

    return roomId!;
  }

  /// Baby unit (caller) ICE restart başlatır.
  /// Yeni offer Firebase'e yazılır; parent bu değişikliği dinleyerek yanıtlar.
  Future<void> initiateIceRestart() async {
    if (!_isCaller || peerConnection == null || roomId == null) return;
    if (_isRestartingIce) return;
    _isRestartingIce = true;

    try {
      debugPrint('ICE restart başlatılıyor...');
      final offer = await peerConnection!.createOffer({'iceRestart': true});
      await peerConnection!.setLocalDescription(offer);

      final offerId = DateTime.now().millisecondsSinceEpoch.toString();
      final roomRef = _db.ref('rooms/$roomId');

      // Eski caller candidates'ları temizle, yenileri toplanacak
      await roomRef.child('callerCandidates').remove();
      await roomRef.child('offer').set({
        'type': offer.type,
        'sdp': offer.sdp,
        'id': offerId,
      });
      debugPrint('ICE restart offer gönderildi (id: $offerId)');
    } catch (e) {
      debugPrint('ICE restart hatası: $e');
    } finally {
      _isRestartingIce = false;
    }
  }

  // ──────────────────────────── PARENT UNIT (Callee) ────────────────────────

  Future<bool> joinRoom(String room) async {
    _isCaller = false;
    _lastProcessedOfferId = null;
    roomId = room;
    final roomRef = _db.ref('rooms/$roomId');

    // İlk offer'ı al (oda varlığı ViewModel'de kontrol edildi)
    final initialSnapshot = await roomRef.child('offer').get();
    if (!initialSnapshot.exists) return false;

    final turnServers = await _fetchIceServers();
    peerConnection = await _createPeerConnection(false, turnServers);

    // İlk offer'ı işle
    final initialData = initialSnapshot.value as Map<dynamic, dynamic>;
    _lastProcessedOfferId = initialData['id'] as String?;

    final offer = RTCSessionDescription(initialData['sdp'], initialData['type']);
    await peerConnection!.setRemoteDescription(offer);

    final answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    final answerId = DateTime.now().millisecondsSinceEpoch.toString();
    await roomRef.child('answer').set({
      'type': answer.type,
      'sdp': answer.sdp,
      'id': answerId,
    });

    // ICE restart offer'larını dinle (ilk offer zaten işlendi, skiplenecek)
    _offerSub = roomRef.child('offer').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null || data['sdp'] == null) return;

      final offerId = data['id'] as String?;
      if (offerId == _lastProcessedOfferId) return; // zaten işlendi
      _lastProcessedOfferId = offerId;

      debugPrint('ICE restart offer alındı (id: $offerId), yanıt oluşturuluyor...');

      final restartOffer = RTCSessionDescription(data['sdp'], data['type']);
      await peerConnection?.setRemoteDescription(restartOffer);

      // Eski callee candidates'ları temizle
      await roomRef.child('calleeCandidates').remove();

      final restartAnswer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(restartAnswer);

      final restartAnswerId = DateTime.now().millisecondsSinceEpoch.toString();
      await roomRef.child('answer').set({
        'type': restartAnswer.type,
        'sdp': restartAnswer.sdp,
        'id': restartAnswerId,
      });
      debugPrint('ICE restart answer gönderildi (id: $restartAnswerId)');
    });

    // Caller ICE candidates - use onValue to handle list refreshes
    _callerCandidatesSub =
        roomRef.child('callerCandidates').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        for (final entry in data.entries) {
          final candidate = entry.value as Map<dynamic, dynamic>?;
          if (candidate != null && candidate['candidate'] != null) {
            peerConnection?.addCandidate(
              RTCIceCandidate(
                candidate['candidate'],
                candidate['sdpMid'],
                candidate['sdpMLineIndex']
              ),
            );
          }
        }
      }
    });

    return true;
  }

  // ──────────────────────────────── CLEANUP ─────────────────────────────────

  Future<void> hangUp() async {
    _offerSub?.cancel();
    _answerSub?.cancel();
    _callerCandidatesSub?.cancel();
    _calleeCandidatesSub?.cancel();

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
