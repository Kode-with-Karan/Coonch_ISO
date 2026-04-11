import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/config.dart';
import 'src/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = await ApiService.create(baseUrl: Config.baseApiUrl);
  runApp(CoonchApp(apiService: apiService));
}
