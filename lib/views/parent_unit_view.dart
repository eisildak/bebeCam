import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../view_models/room_view_model.dart';
import '../core/constants/app_colors.dart';

class ParentUnitView extends StatelessWidget {
  const ParentUnitView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  // Karanlık overlay ve "00:03:12" text
                  Positioned(
                    bottom: 24,
                    right: 40,
                    child: Text(
                      '00:03:12',
                      style: TextStyle(
                        color: AppColors.pastelYellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
                      ),
                    ),
                  ),
                  // BAS KONUŞ Button (overlapping camera and hassasiyet)
                  Positioned(
                    bottom: -30,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.uiAccent.withOpacity(0.9),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 4),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, size: 36, color: AppColors.backgroundDark),
                          SizedBox(height: 4),
                          Text(
                            'BAS\nKONUŞ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.backgroundDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Hassasiyet Alanı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const Text(
                    'HASSASİYET',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.uiAccent,
                      inactiveTrackColor: AppColors.charcoalBlack,
                      thumbColor: Colors.white,
                      trackHeight: 6.0,
                    ),
                    child: Slider(
                      value: 0.4,
                      onChanged: (val) {},
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sessiz', style: TextStyle(color: AppColors.textPrimary)),
                        Text('Ağlama', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBottomBtn(Icons.lightbulb_outline, 'NIGHT\nLIGHT', AppColors.pastelYellow),
                  _buildBottomBtn(Icons.music_note, 'NİNNİ', AppColors.uiAccent),
                  // Volume Slider Button
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.uiAccent,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 40, height: 4, color: AppColors.backgroundDark),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('SES', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  _buildBottomBtn(Icons.history, 'GÖRÜŞME\nGEÇMİŞİ', AppColors.uiAccent),
                  _buildBottomBtn(Icons.settings, 'AYARLAR', AppColors.pastelYellow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBtn(IconData icon, String label, Color bgColor) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.backgroundDark, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
