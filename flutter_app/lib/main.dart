import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Auth Gate
import 'auth_gate.dart';

// Services + Providers
import 'services/api_service.dart';
import 'providers/theme_provider.dart';

// Screens
//    // original splash (corrupted) left in tree
import 'screens/app_splash_screen.dart';   // clean splash used as app entry
import 'screens/user_dashboard.dart';
import 'screens/chatbot_placeholder.dart';
import 'screens/complaint/new_complaint.dart';
import 'screens/complaint/track_complaint.dart';
import 'screens/staff/staff_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/settings/settings_screen.dart';

/// Background notifications — only for Android/iOS (NOT WEB)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable background FCM ONLY on mobile (web does not support it)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
  }

  final api = ApiService();
  runApp(MyApp(api: api));
}

class MyApp extends StatelessWidget {
  final ApiService api;
  const MyApp({Key? key, required this.api}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<ApiService>.value(value: api),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'RailAid',

            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blue,
            ),

            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
            ),

            themeMode: theme.mode,

            // ✅ START APP WITH CLEAN SPLASH
            home: const AppSplashScreen(),

            routes: {
              '/splash': (context) => const AppSplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/forgot': (context) => const ForgotPasswordScreen(),
              '/user': (context) => const UserDashboard(),
              '/complaint/new': (context) => const NewComplaintScreen(),
              '/complaint/track': (context) => const TrackComplaintScreen(),
              '/chatbot': (context) => const ChatbotPlaceholder(),
              '/admin': (context) => const AdminDashboard(),
              '/settings': (context) => const SettingsScreen(),
            },

            onGenerateRoute: (settings) {
              if (settings.name != null &&
                  settings.name!.startsWith('/staff/')) {
                final dept = settings.name!.split('/').last;
                return MaterialPageRoute(
                    builder: (_) => StaffDashboard(department: dept));
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
