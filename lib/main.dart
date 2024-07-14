import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'geoloc.dart';
import 'package:http/http.dart' as http;

int id = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'foodcode_channel',
    'FoodCode Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('beeps_notification'),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  BigPictureStyleInformation bigPictureStyleInformation = await getNotificationImage(
      URL: message.notification!.android!.imageUrl.toString()
  );

  _showOngoingNotification(bigPictureStyleInformation, message, channel);
}

Future<void> _showOngoingNotification(
    BigPictureStyleInformation bigPictureStyleInformation,
    RemoteMessage message,
    AndroidNotificationChannel channel
  ) async {
  const int insistentFlag = 4;

  AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    channel.id,
    channel.name,
    channelDescription: channel.description,
    importance: Importance.max,
    styleInformation: bigPictureStyleInformation,
    priority: Priority.max,
    playSound: true,
    sound: channel.sound,
    enableVibration: true,
    additionalFlags: Int32List.fromList(<int>[insistentFlag]), // keeps the notification playing for a long time.
  );

  NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    id++,
    message.notification!.title,
    message.notification!.body,
    platformChannelSpecifics,
    payload: message.data['link'],
  );
}

Future<BigPictureStyleInformation> getNotificationImage(
    {String URL = ''}) async {
  final http.Response response = await http.get(Uri.parse(URL));

  return BigPictureStyleInformation(
    ByteArrayAndroidBitmap.fromBase64String(base64Encode(response.bodyBytes)),
    largeIcon: ByteArrayAndroidBitmap.fromBase64String(
        base64Encode(response.bodyBytes)),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.getToken();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;
  final String platformBaseUrl = 'https://www.foodcode.ma';
  final String platformBaseRelativeUrl = 'https://foodcode.ma';
  String? mtoken = "";
  Map<String, dynamic>? notificationPayload;
  late AndroidNotificationChannel channel;

  @override
  void initState() {
    super.initState();
    requestPushNotificationPermission();
    getToken();
    initInfo();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            controller.runJavaScriptReturningResult("""
                window.localStorage.setItem("userToken", "$mtoken");
              """);
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) async {
            if (!request.url.startsWith(platformBaseUrl) &&
                !request.url.startsWith(platformBaseRelativeUrl)) {
              return NavigationDecision.prevent;
            }

            if (request.url == "$platformBaseUrl/delivery-man") {
              liveLocation(context, "$platformBaseUrl/store-position", mtoken!);
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(platformBaseUrl));
  }

  Future<void> addUser(String token) async {
    await http.post(
      Uri.parse("$platformBaseUrl/check-token"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'token': token,
      }),
    );
  }

  void requestPushNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  void getToken() async {
    await FirebaseMessaging.instance.getToken().then((token) {
      setState(() {
        mtoken = token;
        debugPrint("My token is $mtoken");
      });
      saveToken(token!);
    });
  }

  String preparePayload(payload) {
    if (payload.startsWith('http')) {
      payload = payload.replaceFirst('http', 'https');
    }

    if (payload.startsWith('/')) {
      payload = payload.replaceFirst('/', '');
    }

    if (!payload.startsWith(platformBaseUrl) ||
        !payload.startsWith(platformBaseRelativeUrl)) {
      return "$platformBaseUrl/$payload";
    }

    return payload;
  }

  Future<dynamic> onSelectNotification(String payload) async {
    payload = preparePayload(payload);

    await controller.loadRequest(Uri.parse(payload));
  }



  initInfo() async {
    channel = const AndroidNotificationChannel(
      'foodcode_channel',
      'FoodCode Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('beeps_notification'),
      enableVibration: true,

    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    var androidInitialize = const AndroidInitializationSettings('ic_launcher');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationSettings =
    InitializationSettings(android: androidInitialize, iOS: iOSInitialize);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        onSelectNotification(notificationResponse.payload ?? '');
      },
      onDidReceiveBackgroundNotificationResponse:
      handleBackgroundNotificationResponse,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
        message.notification!.body.toString(),
        htmlFormatBigText: true,
        contentTitle: message.notification!.title.toString(),
        htmlFormatContentTitle: true,
      );

      BigPictureStyleInformation bigPictureStyleInformation = await getNotificationImage(
          URL: message.notification!.android!.imageUrl.toString()
      );

      _showOngoingNotification(bigPictureStyleInformation, message, channel);
    });
  }



  void saveToken(String token) async {
    await addUser(token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: WillPopScope(
            onWillPop: () async {
              if (await controller.canGoBack()) {
                controller.goBack();
                return false;
              }

              return true;
            },
            child: SafeArea(
              child: WebViewWidget(
                controller: controller,
              ),
            )));
  }
}

void handleBackgroundNotificationResponse(
    NotificationResponse notificationResponse) {
  print("Handling background notification response: ${notificationResponse.payload}");
}