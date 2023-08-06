import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint(fcmToken);
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
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
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
          onNavigationRequest: (NavigationRequest request) {
            if (!request.url.startsWith(platformBaseUrl) && !request.url.startsWith(platformBaseRelativeUrl)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(platformBaseUrl));
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

    if (settings.authorizationStatus == AuthorizationStatus.authorized){
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional){
      debugPrint('User granted PROVISIONAL permission');
    } else {
      debugPrint('User Declined or has not accepted permission');
    }
  }

  void getToken() async {
    await FirebaseMessaging.instance.getToken().then(
            (token){
          setState(() {
            mtoken = token;
            debugPrint("My token is $mtoken");
          });
          saveToken(token!);
        }
    );
  }

  String preparePayload(payload)
  {
    if(payload.startsWith('http')) {
      payload = payload.replaceFirst('http', 'https');
    }

    if(payload.startsWith('/')) {
      payload = payload.replaceFirst('/', '');
    }

    if(!payload.startsWith(platformBaseUrl) || !payload.startsWith(platformBaseRelativeUrl)) {
      return "$platformBaseUrl/$payload";
    }

    return payload;
  }

  Future<dynamic> onSelectNotification(String payload) async {
    payload = preparePayload(payload);
    debugPrint("**......................... notification payload: ............................**");
    debugPrint("**......................... --------------------- ............................**");
    debugPrint("**......................... --------------------- ............................**");
    debugPrint("**......................... --------------------- ............................**");
    debugPrint('**..............**: $payload **.......................**');
    debugPrint("**......................... --------------------- ............................**");
    debugPrint("**......................... --------------------- ............................**");
    debugPrint("**......................... --------------------- ............................**");
    debugPrint("**......................... notification payload: ............................**");

    await controller.loadRequest(Uri.parse(payload));
  }

  initInfo() async {
    var androidInitialize = const AndroidInitializationSettings('ic_launcher');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);

    await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:(NotificationResponse notificationResponse) {
          onSelectNotification(notificationResponse.payload ?? '');
        },
        onDidReceiveBackgroundNotificationResponse: handleBackgroundNotificationResponse,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async{
      debugPrint('**...................onMessage..................**');
      debugPrint('onMessage: ${message.notification?.title}/${message.notification?.body}');

      BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
        message.notification!.body.toString(),
        htmlFormatBigText: true,
        contentTitle: message.notification!.title.toString(),
        htmlFormatContentTitle: true,
      );

      AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'foodcode', 'foodcode', importance: Importance.max,
        styleInformation: bigTextStyleInformation, priority: Priority.max, playSound: true,
      );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics
      );


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
            )
        )
    );
  }
}

void handleBackgroundNotificationResponse(NotificationResponse notificationResponse){
  print("**..........................NOTIFIACTION RESPONSE.......................**");
  print(notificationResponse);
  print("**..........................END NOTIFIACTION RESPONSE.......................**");

}
