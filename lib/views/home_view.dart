import 'package:flutter/material.dart';
import '../../view_models/room_view_model.dart';
import '../models/device_role.dart';
import 'package:provider/provider.dart';
import 'baby_unit_view.dart';
import 'parent_unit_view.dart';
import '../core/constants/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeView extends StatelessWidget {
  const HomeView({Key? key}) : super(key: key);

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
    final TextEditingController _roomCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundDim,
        title: const Text('Oda Kodunu Girin', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _roomCtrl,
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
              if (_roomCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                await vm.initRenderers();
                await vm.startParentUnit(_roomCtrl.text);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParentUnitView()),
                  );
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
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assests/icon/appicon.png',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                      print("WebRTC Error: $e\n$stackTrace");
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
                    foregroundColor: AppColors.backgroundDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    bool granted = await _checkPermissions(context);
                  if (!granted) return;
                    vm.selectRole(DeviceRole.parent);
                    _showJoinRoomDialog(context, vm);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
