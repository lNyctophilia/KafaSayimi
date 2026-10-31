import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool isPWA() {
  final isStandalone = web.window.matchMedia('(display-mode: standalone)').matches;
  
  // Sadece standalone'u kontrol ediyoruz, minimal-ui mobil tarayıcılarda yanıltıcı olabiliyor.
  return isStandalone;
}

bool isMobileBrowser() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('iphone') || 
         userAgent.contains('ipad') || 
         userAgent.contains('android') ||
         userAgent.contains('mobile');
}

bool requiresEmailForNotifications() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad');
  final hasPushManager = web.window.hasProperty('PushManager'.toJS);
  
  return isIOS && !hasPushManager.toDart;
}

