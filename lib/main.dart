import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'app.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

// Vangt fouten binnen Flutter's widget-systeem (layout, rendering, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // blijft ook gewoon in je console tonen
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Vangt overige Dart-fouten die buiten Flutter's widget-systeem gebeuren
  // (bijv. in een async functie, een Future die faalt, etc.)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };


  await NotificationService().init();
  runApp(const MyApp());
}
