import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audioplayers/audioplayers.dart';
import '../view_models/room_view_model.dart';
import '../core/constants/app_colors.dart';

class BabyUnitView extends StatefulWidget {
  const BabyUnitView({super.key});

  @override
  State<BabyUnitView> createState() => _BabyUnitViewState();
}

class _BabyUnitViewState extends State<BabyUnitView> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _activeSound = '';
  bool _isPTTActive = false;

  late RoomViewModel _vm;
  late AnimationController _micAnimController;
  late Animation<double> _micAnimation;

  @override
  void initState() {
    super.initState();
    _micAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true); // Sürekli nefes alıp verir gibi büyü/küçül

    _micAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micAnimController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<RoomViewModel>();
      _vm.addListener(_onRoomViewModelChange);
      
      _vm.onRoomEnded = () {
        if (mounted) {
          _vm.hangUp();
          Navigator.pop(context);
        }
      };
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_onRoomViewModelChange);
    _vm.onRoomEnded = null;
    _micAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onRoomViewModelChange() async {
    // Volume Control Logic
    if (_audioPlayer.volume != _vm.babyVolume) {
      _audioPlayer.setVolume(_vm.babyVolume);
    }

    if (_vm.activeSound != _activeSound) {
      _activeSound = _vm.activeSound;
      try {
        if (_activeSound.isEmpty) {
          await _audioPlayer.stop();
        } else {
          String path = '';
          if (_activeSound == 'B.Gürültü') {
            path = 'audio/noise.mp3';
          } else if (_activeSound == 'Yağmur') path = 'audio/rain.mp3';
          else if (_activeSound == 'Ninni') path = 'audio/lullaby.mp3';
          
          if (path.isNotEmpty) {
            await _audioPlayer.setReleaseMode(ReleaseMode.loop);
            await _audioPlayer.play(AssetSource(path));
          }
        }
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Audio Play Error: $e");
      }
    }
  }

  void _toggleSound(String soundType) {
    if (_vm.activeSound == soundType) {
      _vm.setActiveSound('');
    } else {
      _vm.setActiveSound(soundType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.read<RoomViewModel>().hangUp();
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Consumer<RoomViewModel>(
        builder: (context, vm, child) {
          return Stack(
            children: [
              // Canlı Kamera Önizlemesi (Arka Planda)
              if (vm.localRenderer.srcObject != null)
                Positioned.fill(
                  child: RTCVideoView(
                    vm.localRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              
              // Siyah yarı saydam perde (Yazıların okunabilmesi için)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),

              // NIGHT LIGHT EKRANI - Parlak sarı aydınlatma
              if (vm.isNightLightOn)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFFFF0C2),
                  ),
                ),

              // RECONNECTING OVERLAY
              if (vm.isReconnecting)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.75),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          'Yeniden bağlanıyor...',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 48), // Geri butonu için boşluk
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'BEBEK ODASI',
                                style: TextStyle(
                                  color: AppColors.uiAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (vm.roomId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.charcoalBlack,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'ODA KODU: ${vm.roomId}',
                                    style: const TextStyle(
                                      color: AppColors.pastelYellow,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4.0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () {
                            vm.hangUp();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    const SizedBox(height: 32),
                    
                    // BAS KONUŞ Button (Ortada ve daha büyük)
                    GestureDetector(
                      onTapDown: (_) {
                        setState(() => _isPTTActive = true);
                        context.read<RoomViewModel>().setMicrophoneEnabled(true);
                      },
                      onTapUp: (_) {
                        setState(() => _isPTTActive = false);
                        context.read<RoomViewModel>().setMicrophoneEnabled(false);
                      },
                      onTapCancel: () {
                        setState(() => _isPTTActive = false);
                        context.read<RoomViewModel>().setMicrophoneEnabled(false);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isPTTActive ? 95 : 105,
                        height: _isPTTActive ? 95 : 105,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPTTActive ? Colors.redAccent : AppColors.uiAccent.withOpacity(0.9),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          boxShadow: _isPTTActive 
                            ? [] 
                            : [BoxShadow(color: AppColors.uiAccent.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, size: 40, color: _isPTTActive ? Colors.white : AppColors.backgroundDark),
                            const SizedBox(height: 4),
                            Text(
                              'BAS\nKONUŞ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isPTTActive ? Colors.white : AppColors.backgroundDark,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Ortam Sesi Aktarılıyor (Mic Indicator) - Merkezde
                    if (vm.isConnected)
                      Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDim.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.uiAccent.withOpacity(0.5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.uiAccent.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _micAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _micAnimation.value,
                                      child: child,
                                    );
                                  },
                                  child: const Icon(
                                    Icons.mic,
                                    size: 16,
                                    color: AppColors.uiAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ortam Sesi Aktarılıyor',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                    const SizedBox(height: 16),
                    
                    // Sound Options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.charcoalBlack.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSoundItem(
                              icon: Icons.waves, 
                              label: 'B.Gürültü', 
                              isSelected: vm.activeSound == 'B.Gürültü', 
                              onTap: () => _toggleSound('B.Gürültü'),
                            ),
                            _buildSoundItem(
                              icon: Icons.water_drop_outlined, 
                              label: 'Yağmur', 
                              isSelected: vm.activeSound == 'Yağmur', 
                              onTap: () => _toggleSound('Yağmur'),
                            ),
                            _buildSoundItem(
                              icon: Icons.child_care, 
                              label: 'Ninni', 
                              isSelected: vm.activeSound == 'Ninni', 
                              onTap: () => _toggleSound('Ninni'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ],
          );
        },
      ),
    ),
    );
  }

  Widget _buildSoundItem({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.uiAccent : AppColors.charcoalBlack,
              border: Border.all(
                color: isSelected ? AppColors.uiAccent : AppColors.textSecondary.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppColors.uiAccent.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.charcoalBlack : AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
