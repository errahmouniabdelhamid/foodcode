import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:slack_logger/slack_logger.dart';

final SlackLogger _slack = SlackLogger.instance;

Future<void> _showMyDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('AlertDialog Title'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('This is a demo alert dialog.'),
              Text('Would you like to approve of this message?'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Enable'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> _showLocationServicesDisabledDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Please Enable Location Services'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Please Enable Location Services (GPS)'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Ok'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}


Future<http.Response> _storePosition(String url, String token, String lat, String lon) {
  return http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'token': token,
      'lat': lat,
      'lon': lon,
    }),
  );
}

void _geoLocalisationCheck(BuildContext context) async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    _showLocationServicesDisabledDialog(context);
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    _showMyDialog(context);
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }
}

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<Position> determinePosition(BuildContext context) async {

  _geoLocalisationCheck(context);

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
  );
}

void liveLocation(BuildContext context, String storeUrl, String token) {
  _geoLocalisationCheck(context);

  LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      //forceLocationManager: true,
      intervalDuration: const Duration(seconds: 2),
      //(Optional) Set foreground notification config to keep the app alive
      //when going to the background
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText:
        "Foodcode app will continue to receive your location even when you aren't using it",
        notificationTitle: "Running in Background",
        enableWakeLock: true,
      )
  );

  StreamSubscription<Position> positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position? position) {
    if(position == null){
      // print('Unknown');
      // _slack.send("Unknown");
    }else{
      _storePosition(storeUrl, token, position.latitude.toString(), position.longitude.toString());
      _slack.send("long:${position.latitude.toString()}, lat:${position.longitude.toString()}");
      // print("**................Stream Location.....................***");
      // print("**....................................................***");
      // print("**................Stream Location.....................***");
      // print("**....................................................***");
      // print('long:${position.latitude.toString()}, lat:${position.longitude.toString()}');
      // print("**................Stream Location.....................***");
      // print("**....................................................***");
      // print("**................Stream Location.....................***");
      // print("**....................................................***");
    }
  });
}