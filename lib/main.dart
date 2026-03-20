import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/api_service.dart';
import 'src/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create ApiService (loads persisted token if any)
  final api = await ApiService.create(baseUrl: Config.baseApiUrl);

  runApp(CoonchApp(apiService: api));
}
