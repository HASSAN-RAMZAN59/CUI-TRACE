// main.dart - App Entry Point
import 'package:flutter/foundation.dart' show kIsWeb, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Services
import './services/app_service.dart';

// Screens
import './screens/splash_screen.dart';
import './screens/onboarding_screen.dart';
import './screens/login_screen.dart';
import './screens/signup_screen.dart';
import './screens/home_screen.dart';
import './screens/profile_screen.dart';
import './screens/add_item_screen.dart';
import './screens/detail_screen.dart';
import './screens/edit_item_screen.dart';
import './screens/chat_list_screen.dart';
import './screens/chat_screen.dart';
import './screens/notifications_screen.dart';
import './screens/forgetPassword_screen.dart';
import './screens/verification_screen.dart';

// Models
import './models/item_model.dart';

// Initialize notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Global navigator key for notification taps
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// App Service instance
final AppService appService = AppService();

// Initialize local notifications
Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        print('👆 Local notification tapped with payload: ${response.payload}');
        _handleNotificationTapFromPayload(response.payload!);
      }
    },
  );
}

// Handle notification tap from payload
void _handleNotificationTapFromPayload(String payload) {
  try {
    print('📋 Payload received: $payload');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        Navigator.pushNamed(
          navigatorKey.currentContext!,
          '/notifications',
        );
      }
    });
  } catch (e) {
    print('❌ Error handling notification tap: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }

  try {
    print("🔄 Initializing App...");
    await _initializeLocalNotifications();
    await appService.initializeFCM();
    print("✅ App initialized successfully!");

    runApp(const MyApp());
  } catch (e) {
    print("❌ Initialization error: $e");
    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;

  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Text(
                  'Error: $errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    main();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Handle notification tap with data
void _handleNotificationTap(Map<String, dynamic> data) {
  print('🔗 Handling notification tap with data: $data');

  final type = data['type']?.toString() ?? '';
  final context = navigatorKey.currentContext;

  if (context == null) {
    print('⚠️ No context available for navigation');
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      switch (type) {
        case 'new_item':
        case 'item_claimed':
        case 'verification_attempt':
          final itemId = data['itemId']?.toString();
          if (itemId != null && itemId.isNotEmpty) {
            Navigator.pushNamed(
              context,
              '/detail',
              arguments: itemId,
            );
          }
          break;

        case 'chat_message':
          final chatId = data['chatId']?.toString();
          final senderId = data['senderId']?.toString();
          final senderName = data['senderName']?.toString() ?? 'User';
          final itemId = data['itemId']?.toString();
          final itemTitle = data['itemTitle']?.toString();

          if (chatId != null && chatId.isNotEmpty) {
            Navigator.pushNamed(
              context,
              '/chat',
              arguments: {
                'chatId': chatId,
                'otherUserId': senderId,
                'otherUserName': senderName,
                'itemId': itemId,
                'itemTitle': itemTitle,
              },
            );
          }
          break;

        default:
          Navigator.pushNamed(context, '/notifications');
      }
    } catch (e) {
      print('❌ Error during navigation: $e');
      Navigator.pushNamed(context, '/notifications');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CUI Trace',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/add_item': (context) => const AddItemScreen(),
        '/detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is ItemModel) {
            return ItemDetailScreen(item: args);
          } else if (args is String && args.isNotEmpty) {
            return FutureBuilder<ItemModel?>(
              future: appService.getItemById(args),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Item Details')),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Item Not Found')),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 60, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text('Item not found or deleted', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                            child: const Text('Return to Home'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ItemDetailScreen(item: snapshot.data!);
              },
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Item details not provided', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                    child: const Text('Return to Home'),
                  ),
                ],
              ),
            ),
          );
        },
        '/edit_item': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is ItemModel) {
            return EditItemScreen(item: args, itemId: args.id);
          } else if (args is String && args.isNotEmpty) {
            return EditItemScreen(itemId: args);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Item not provided')),
          );
        },
        '/verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is ItemModel) {
            return VerificationScreen(item: args);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Item not provided')),
          );
        },
        '/chats': (context) => const ChatListScreen(),
        '/notifications': (context) => const NotificationsScreen(),
      },
      onGenerateRoute: (settings) {
        print('🔄 Generating route: ${settings.name}');
        print('Arguments type: ${settings.arguments?.runtimeType}');

        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>?;

          if (args == null) {
            return MaterialPageRoute(
              builder: (context) => const ChatListScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: args['chatId'] ?? '',
              otherUserId: args['otherUserId'] ?? '',
              otherUserName: args['otherUserName'] ?? 'Unknown User',
              itemId: args['itemId'],
              itemTitle: args['itemTitle'],
            ),
          );
        }

        if (settings.name?.startsWith('/item/') == true) {
          final itemId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<ItemModel?>(
              future: appService.getItemById(itemId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Loading...')),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Item Not Found')),
                    body: const Center(child: Text('Item not found or deleted')),
                  );
                }
                return ItemDetailScreen(item: snapshot.data!);
              },
            ),
          );
        }

        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    'Page not found: ${settings.name}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}