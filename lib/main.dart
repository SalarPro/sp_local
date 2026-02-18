import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/screens/my_app/my_app.dart';
import 'src/services/ai_translation_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AiTranslationService.initialize();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
