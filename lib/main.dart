
import 'package:final_project/Screen/WelcomeScreen/WelcomeScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import 'Screen/Bottom_nav_bar/Main_Nav_Bar.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool hasSeenWelcome = prefs.getBool('hasSeenWelcomeScreen') ?? false;

  runApp(MyApp(hasSeenWelcome: hasSeenWelcome));
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcome;
  
  const MyApp({super.key, required this.hasSeenWelcome});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: hasSeenWelcome ? MainNavBar() : const Welcomescreen(),
    );
  }
}
