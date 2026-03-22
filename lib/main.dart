import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'view_models/room_view_model.dart';
import 'views/splash_view.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Android'de google-services.json native olarak Firebase'i daha dart kodu çalışmadan 
    // başlattığı için bazen duplicate-app hatası döner, bu durumu yoksayıyoruz.
  }

  runApp(const BebeCamApp());
}

class BebeCamApp extends StatelessWidget {
  const BebeCamApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
      ],
      child: MaterialApp(
        title: 'BebeCam',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashView(),
      ),
    );
  }
}
