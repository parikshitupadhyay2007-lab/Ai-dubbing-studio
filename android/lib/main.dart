import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OtakuDubApp());
}

class OtakuDubApp extends StatelessWidget {
  const OtakuDubApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OtakuDub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF9A83D9)),
    home: const Scaffold(
      body: Center(child: Text('OtakuDub · Powered by Blackheart')),
    ),
  );
}
