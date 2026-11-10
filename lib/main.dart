import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'fcm_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('onBackgroundMessage: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FCMService _fcmService = FCMService();
  static const _assets = {
    'default': 'assets/images/default.png',
    'promo': 'assets/images/promo.png',
  };
  String _statusText = 'Waiting for a cloud message';
  String _imagePath = 'assets/images/default.png';
  String _feedback = 'Initializing messaging...';
  String _lastHandler = 'None yet';
  String _lastMessageId = 'None yet';
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeMessaging());
  }

  void _report(String text) {
    debugPrint(text);
    if (mounted) setState(() => _feedback = text);
  }

  Future<void> _initializeMessaging() async {
    try {
      await _fcmService.initialize(
        onData: _handleMessage,
        onStatus: _report,
      );
    } on FirebaseException catch (error, stack) {
      debugPrint('Firebase error: $error\n$stack');
      _report('Messaging error (${error.code}): ${error.message}');
    } on StateError catch (error, stack) {
      debugPrint('Messaging setup error: $error\n$stack');
      _report(error.message.toString());
    }
  }

  void _handleMessage(RemoteMessage message, String source) {
    if (!mounted) return;
    setState(() {
      _lastHandler = source;
      _lastMessageId = message.messageId ?? '(no ID)';
      _messageCount += 1;
    });
    final path = _assets[message.data['asset']];
    if (message.data['action'] != 'update_ui' || path == null) {
      _report('Rejected payload: use action=update_ui and '
          'asset=default or asset=promo. Previous content preserved.');
      return;
    }
    setState(() {
      _statusText = message.notification?.title ?? 'Payload received';
      _imagePath = path;
      _feedback = 'Applied payload ${message.messageId ?? "(no ID)"}';
    });
  }

  @override
  void dispose() {
    unawaited(_fcmService.dispose().catchError(
      (Object error, StackTrace stack) {
        debugPrint('FCM cleanup error: $error\n$stack');
      },
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity 14: FCM')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_statusText, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Image.asset(
            _imagePath,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) {
              debugPrint('Asset load error: $error');
              return Text('Cannot load $_imagePath. Check setup phase 3.');
            },
          ),
          const SizedBox(height: 16),
          Text('Last handler: $_lastHandler'),
          Text('Messages handled this launch: $_messageCount'),
          Text('Last message ID: $_lastMessageId'),
          const SizedBox(height: 16),
          Text(_feedback),
        ],
      ),
    );
  }
}