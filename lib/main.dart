import 'package:flutter/material.dart';
import 'package:mapbox_map/map.dart';
import 'package:mapbox_map/flutter_map_cache/page.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FlutterMapCachePage(),
    );
  }
}
