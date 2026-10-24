import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const TempoAlertaApp());

class TempoAlertaApp extends StatelessWidget {
  const TempoAlertaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TempoAlerta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const HomeScreen(),
      );
}
