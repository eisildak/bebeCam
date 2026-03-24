import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../view_models/room_view_model.dart';
import '../core/constants/app_colors.dart';

class ParentUnitView extends StatefulWidget {
  const ParentUnitView({super.key});

  @override
  State<ParentUnitView> createState() => _ParentUnitViewState();
}

class _ParentUnitViewState extends State<ParentUnitView> {
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isPTTActive = false;
  double _volume = 0.8;
  bool _isMuted = false;
  RoomViewModel? _vm;

  @override
  void initState() {
    super.initState();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<RoomViewModel>();
      _vm!.onRoomEnded = () {
        if (mounted) {
          _vm!.hangUp();
          Navigator.pop(context);
        }
      };
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vm?.onRoomEnded = null;
    super.dispose();
  }

  String get _formattedTime {
    int hours = _secondsElapsed ~/ 3600;
    int minutes = (_secondsElapsed % 3600) ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
        body: SafeArea(
          child: Column(
            children: [
              // Top Header: Bebek İzle & BAĞLANDI
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bebek İzle',
                      style: TextStyle(
                        color: AppColors.pastelYellow,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'BAĞLANDI',
                          style: TextStyle(
                            color: AppColors.uiAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.softGreen,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.softGreen.withOpacity(0.6),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 28),
                          onPressed: () {
                            context.read<RoomViewModel>().hangUp();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Camera Feed Area
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Consumer<RoomViewModel>(
                      builder: (context, vm, child) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalBlack,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: RTCVideoView(
                              vm.remoteRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                          ),
                        );
                      },
                    ),
                    // Karanlık overlay ve zaman sayacı text'i
                    Positioned(
                      bottom: 24,
                      right: 40,
                      child: Text(
                        _formattedTime,
                        style: TextStyle(
                          color: AppColors.pastelYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Ses Seviyesi Alanı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'SES SEVİYESİ',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: _isMuted ? Colors.redAccent : AppColors.uiAccent,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                              context.read<RoomViewModel>().setRemoteAudioEnabled(!_isMuted);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _isMuted ? AppColors.charcoalBlack : AppColors.uiAccent,
                        inactiveTrackColor: AppColors.charcoalBlack,
                        thumbColor: _isMuted ? Colors.grey : Colors.white,
                        trackHeight: 6.0,
                      ),
                      child: Slider(
                        value: _isMuted ? 0.0 : _volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            _volume = val;
                            if (val == 0.0) {
                              _isMuted = true;
                              context.read<RoomViewModel>().setRemoteAudioEnabled(false);
                            } else {
                              if (_isMuted) {
                                _isMuted = false;
                                context.read<RoomViewModel>().setRemoteAudioEnabled(true);
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Bottom Action Bar - Sadeleştirilmiş (3 buton, merkeze hizalı)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Consumer<RoomViewModel>(
                  builder: (context, vm, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBottomBtn(
                          Icons.lightbulb_outline, 
                          'GECE\nLAMBASI', 
                          vm.isNightLightOn ? Colors.white : AppColors.pastelYellow,
                          isActive: vm.isNightLightOn,
                          onTap: () {
                            vm.toggleNightLight(!vm.isNightLightOn);
                          }
                        ),
                        const SizedBox(width: 32),
                        
                        // BAS KONUŞ Button (Ortada)
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
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _isPTTActive ? 72 : 64,
                                height: _isPTTActive ? 72 : 64,
                                decoration: BoxDecoration(
                                  color: _isPTTActive ? Colors.redAccent : AppColors.uiAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: _isPTTActive ? [] : [BoxShadow(color: AppColors.uiAccent.withOpacity(0.6), blurRadius: 16, spreadRadius: 4)],
                                ),
                                child: Icon(Icons.mic, color: _isPTTActive ? Colors.white : AppColors.backgroundDark, size: _isPTTActive ? 36 : 30),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'BAS KONUŞ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isPTTActive ? Colors.redAccent : AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 32),
                        _buildBottomBtn(
                          Icons.music_note, 
                          'NİNNİ', 
                          vm.activeSound.isNotEmpty ? Colors.white : AppColors.uiAccent,
                          isActive: vm.activeSound.isNotEmpty,
                          onTap: () {
                            _showNinniDialog(context, vm);
                          }
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBtn(IconData icon, String label, Color bgColor, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 72 : 64,
            height: isActive ? 72 : 64,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: isActive ? [BoxShadow(color: bgColor.withOpacity(0.6), blurRadius: 16, spreadRadius: 4)] : [],
            ),
            child: Icon(icon, color: AppColors.backgroundDark, size: isActive ? 32 : 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? bgColor : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showNinniDialog(BuildContext context, RoomViewModel initialVm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return Consumer<RoomViewModel>(
          builder: (context, vm, child) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ninni & Ses Seçimi', style: TextStyle(color: AppColors.pastelYellow, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildNinniOption(context, vm, Icons.waves, 'B.Gürültü'),
                              const SizedBox(height: 12),
                              _buildNinniOption(context, vm, Icons.water_drop_outlined, 'Yağmur'),
                              const SizedBox(height: 12),
                              _buildNinniOption(context, vm, Icons.child_care, 'Ninni'),
                              const SizedBox(height: 12),
                              _buildNinniOption(context, vm, Icons.stop_circle_outlined, 'Sesi Kapat', isStop: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Dikey Ses Ayarı
                        Container(
                          height: 250,
                          width: 64,
                          decoration: BoxDecoration(
                            color: AppColors.charcoalBlack,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.uiAccent.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                            ]
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  vm.babyVolume == 0 ? Icons.volume_off : Icons.volume_up, 
                                  color: vm.babyVolume == 0 ? Colors.redAccent : AppColors.uiAccent, 
                                  size: 24
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: AppColors.uiAccent,
                                        inactiveTrackColor: AppColors.backgroundDark,
                                        thumbColor: Colors.white,
                                        trackHeight: 12.0,
                                        overlayShape: SliderComponentShape.noOverlay,
                                      ),
                                      child: Slider(
                                        value: vm.babyVolume,
                                        min: 0.0,
                                        max: 1.0,
                                        onChanged: (val) {
                                          vm.setBabyVolume(val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(vm.babyVolume * 100).toInt()}%',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildNinniOption(BuildContext context, RoomViewModel vm, IconData icon, String label, {bool isStop = false}) {
    bool isSelected = vm.activeSound == label;
    return InkWell(
      onTap: () {
        vm.setActiveSound(isStop ? '' : label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.uiAccent.withOpacity(0.2) : AppColors.charcoalBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.uiAccent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isStop ? Colors.redAccent : (isSelected ? AppColors.uiAccent : AppColors.textPrimary)),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: isStop ? Colors.redAccent : AppColors.textPrimary, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
