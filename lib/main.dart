import 'package:can_host/models/can_model.dart';
import 'package:can_host/protocol/can_protocol.dart';
import 'package:can_host/screens/home_route.dart';
import 'package:flutter/material.dart';
import 'package:can_host/models/telemetry_model.dart';
import 'package:can_host/models/parameter_table_model.dart';
import 'package:provider/provider.dart';

import 'misc/config_data.dart';
import 'models/file_model.dart';
import 'models/screen_model.dart';

const homeRoute = '/';

void main() {
  runApp(const CanHostApp());
}

class CanHostApp extends StatelessWidget {
  const CanHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    // declare classes for dependency injection here
    final canApi = CANApi();
    final configData = ConfigData();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScreenModel>(
            create: (context) => ScreenModel()),
        ChangeNotifierProvider<TelemetryModel>(
            create: (context) => TelemetryModel(canApi, configData)),
        ChangeNotifierProvider<ParameterTableModel>(
            create: (context) => ParameterTableModel(configData)),
        ChangeNotifierProvider<FileModel>(
            create: (context) => FileModel(canApi, configData)),
        ChangeNotifierProvider<ParameterTableModel>(
            create: (context) => ParameterTableModel(configData)),
        ChangeNotifierProvider<CanModel>(
            create: (context) => CanModel(canApi, configData)),
      ],
      child: MaterialApp(
        title: 'Serial Host',
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: Colors.black,
          appBarTheme: const AppBarTheme(
            color: Colors.white,
            foregroundColor: Colors.black,
          ),
          textTheme: const TextTheme(
            titleSmall: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal, color: Colors.black),
            displayLarge: TextStyle(fontSize: 25.0, fontWeight: FontWeight.normal, color: Colors.white),
            titleLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Colors.black),
            titleMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Colors.black),
          ),
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.grey),
        ),
        initialRoute: homeRoute,
        routes: {
          homeRoute: (context) => const HomeRoute(),
        },
      ),
    );
  }
}
