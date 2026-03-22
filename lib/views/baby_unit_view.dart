import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../view_models/room_view_model.dart';
import '../core/constants/app_colors.dart';

class BabyUnitView extends StatelessWidget {
  const BabyUnitView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    
                    // Center Animation
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.backgroundDim.withOpacity(0.8),
                        border: Border.all(
                          color: AppColors.uiAccent.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mic_none,
                          size: 64,
                          color: AppColors.uiAccent,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'Ortam Sesi\nAktarılıyor...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Sound Options (Mock)
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
                            _buildSoundItem(Icons.waves, 'B.Gürültü', true),
                            _buildSoundItem(Icons.water_drop_outlined, 'Yağmur', false),
                            _buildSoundItem(Icons.child_care, 'Ninni', false),
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
    );
  }

  Widget _buildSoundItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.uiAccent : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppColors.uiAccent : AppColors.textSecondary,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppColors.backgroundDark : AppColors.textPrimary,
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
    );
  }
}
