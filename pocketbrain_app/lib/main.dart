
import 'package:flutter/material.dart';

import 'data/document_store.dart';
import 'data/collection_store.dart';
import 'data/settings_store.dart';

import 'pages/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DocumentStore.instance.initialize();

  await CollectionStore.instance.initialize();

  await SettingsStore.instance.initialize();

  runApp(const LociqraApp());
}

class LociqraApp extends StatelessWidget {
  const LociqraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lociqra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
