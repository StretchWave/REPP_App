import 'package:ai_fitness_tracker/screens/home_screen.dart';
import 'package:ai_fitness_tracker/screens/login_screen.dart'; // Import Login

import 'package:ai_fitness_tracker/widgets/ai_status_overlay.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_fitness_tracker/core/constants.dart';
import 'package:ai_fitness_tracker/services/settings_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await SettingsService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REPP',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return GlobalAiOverlay(child: child!);
      },
      home: Supabase.instance.client.auth.currentUser != null
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
