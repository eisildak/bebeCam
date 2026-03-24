import 'package:flutter/material.dart';
import '../view_models/room_view_model.dart';
import '../models/device_role.dart';
import 'package:provider/provider.dart';
import 'baby_unit_view.dart';
import 'parent_unit_view.dart';
import '../core/constants/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<bool> _checkPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isPermanentlyDenied || 
        statuses[Permission.microphone]!.isPermanentlyDenied ||
        statuses[Permission.camera]!.isDenied ||
        statuses[Permission.microphone]!.isDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.backgroundDim,
            title: const Text('İzin Gerekli', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'Uygulamanın çalışması için Kamera ve Mikrofon iznine ihtiyacı var. Lütfen ayarlardan izin verin.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İPTAL', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.uiAccent),
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(ctx);
                },
                child: const Text('AYARLARI AÇ', style: TextStyle(color: AppColors.backgroundDark)),
              )
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }

  void _showJoinRoomDialog(BuildContext context, RoomViewModel vm) {
    final TextEditingController roomCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundDim,
        title: const Text('Oda Kodunu Girin', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: roomCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Örn: 1234',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.uiAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.uiAccent),
            onPressed: () async {
              if (roomCtrl.text.isNotEmpty) {
                String code = roomCtrl.text;
                Navigator.pop(context);
                
                await vm.initRenderers();
                
                bool success = await vm.startParentUnit(code);
                if (success) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ParentUnitView()),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Böyle bir oda kodu bulunamadı! Lütfen kontrol edin.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('BAĞLAN', style: TextStyle(color: AppColors.backgroundDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<RoomViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A24), 
              AppColors.backgroundDark,
              AppColors.charcoalBlack,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Image.asset(
                            'assets/icon/appicon.png',
                            height: 120,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'BebeCam',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Görüntülü Bebek Telsizi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 60),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.videocam_outlined),
                            label: const Text('Bebek Ünitesi (Kamera)'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              backgroundColor: AppColors.backgroundDim,
                              foregroundColor: AppColors.uiAccent,
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.5),
                              side: BorderSide(color: AppColors.uiAccent.withOpacity(0.5), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                bool granted = await _checkPermissions(context);
                                if (!granted) return;
                                vm.selectRole(DeviceRole.baby);
                                await vm.initRenderers();
                                await vm.startBabyUnit(context);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const BabyUnitView()),
                                  );
                                }
                              } catch (e, stackTrace) {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Kamera Hatası'),
                                      content: Text('Kamera açılamadı:\n$e'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Tamam'),
                                        )
                                      ],
                                    ),
                                  );
                                }
                                debugPrint("WebRTC Error: $e\n$stackTrace");
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.phone_iphone),
                            label: const Text('Ebeveyn Ünitesi (İzleyici)'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              backgroundColor: AppColors.uiAccent,
                              foregroundColor: AppColors.charcoalBlack,
                              elevation: 12,
                              shadowColor: AppColors.uiAccent.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              bool granted = await _checkPermissions(context);
                              if (!granted) return;
                              vm.selectRole(DeviceRole.parent);
                              _showJoinRoomDialog(context, vm);
                            },
                          ),
                          const Spacer(),
                          const SizedBox(height: 24),
                          const Text(
                            '© 2026\nDeveloped by Erol Isildak',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              letterSpacing: 1.2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
