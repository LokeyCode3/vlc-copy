 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/media_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/player_provider.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait by default; video player overrides this
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  final storage = await StorageService.getInstance();

  runApp(VLCApp(storage: storage));
}

class VLCApp extends StatelessWidget {
  final StorageService storage;

  const VLCApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => MediaProvider(storage)),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(
          create: (ctx) {
            final player = PlayerProvider();
            player.onPositionUpdate = (id, pos) {
              ctx.read<MediaProvider>().updateLastPosition(id, pos);
            };
            return player;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (ctx, settings, _) {
          return MaterialApp(
            title: 'ISPC Player',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
