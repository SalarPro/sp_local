import 'package:flutter/material.dart';
import 'package:sp_local/src/screens/home/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'ibm_arabic',
      ),
      home: const HomePage(),
    );
  }
}
