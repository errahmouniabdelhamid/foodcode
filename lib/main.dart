import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'geoloc.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseMessaging.instance.getToken();

  // debugPrint(fcmToken);
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
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Map<String, dynamic>? notificationPayload;

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
              // Position position = await determinePosition(context);

              liveLocation(context, "$platformBaseUrl/store-position", mtoken!);
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(platformBaseUrl));
  }

  Future<void> addUser(String token) async {
    // Call the user's CollectionReference to add a new user
    http.post(
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

    // if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    //   // debugPrint('User granted permission');
    // } else if (settings.authorizationStatus ==
    //     AuthorizationStatus.provisional) {
    //   // debugPrint('User granted PROVISIONAL permission');
    // } else {
    //   // debugPrint('User Declined or has not accepted permission');
    // }
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

  Future<BigPictureStyleInformation> getNotificationImage(
      {String URL = ''}) async {
    final http.Response response = await http.get(Uri.parse(URL));

    return BigPictureStyleInformation(
      ByteArrayAndroidBitmap.fromBase64String(base64Encode(response.bodyBytes)),
      largeIcon: ByteArrayAndroidBitmap.fromBase64String(
          base64Encode(response.bodyBytes)),
    );
  }

  initInfo() async {
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

      BigPictureStyleInformation bigPictureStyleInformation =
          await getNotificationImage(
              URL: message.notification!.android!.imageUrl.toString());
      final sound = 'beeps_notification.wav';
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'foodcode',
        'foodcode',
        sound: RawResourceAndroidNotificationSound(sound.split('.').first),
        importance: Importance.max,
        styleInformation: bigPictureStyleInformation,
        priority: Priority.max,
        playSound: true,
        ongoing: true,
      );

      NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0,
        message.notification!.title,
        message.notification!.body,
        platformChannelSpecifics,
        payload: message.data['link'],
      );
    });
  }

  void saveToken(String token) async {
    // make api request to store token
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
  // print("**..........................NOTIFIACTION RESPONSE.......................**");
  // print(notificationResponse);
  // print("**..........................END NOTIFIACTION RESPONSE.......................**");
}
