import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize notifications
  Future<void> initialize(String userId) async {
    try {
      // 1. Request user permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('User granted notification permission');
        }
        
        // 2. Fetch and store FCM token in DB
        await _saveDeviceToken(userId);

        // 3. Setup token refresh listener
        _fcm.onTokenRefresh.listen((token) async {
          await _updateTokenInFirestore(userId, token);
        });

        // 4. Set up message handlers
        _setupMessageHandlers();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  // Get current device token and save to DB
  Future<void> _saveDeviceToken(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _updateTokenInFirestore(userId, token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM device token: $e');
      }
    }
  }

  // Helper method to write to Firestore
  Future<void> _updateTokenInFirestore(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'pushToken': token,
    });
  }

  // Handle messages in different app states
  void _setupMessageHandlers() {
    // 1. Foreground messaging (App is open and running in view)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Received a foreground message: ${message.notification?.title}');
      }
      // You could display an in-app banner widget here
    });

    // 2. Background click (App was in background, user clicked notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('App opened from notification: ${message.data}');
      }
      // You can navigate the user to the active chat room here
    });
  }
}
