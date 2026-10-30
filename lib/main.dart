import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/app_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // İlk açılışta arka planda otomatik ve sessizce güncelleme / önbellek kontrolü
  unawaited(AppUpdateService.initialize());

  runApp(const ProviderScope(child: KafaSayimiApp()));
}

