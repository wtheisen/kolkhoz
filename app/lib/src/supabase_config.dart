import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KolkhozSupabaseConfig {
  const KolkhozSupabaseConfig._();

  static const url = String.fromEnvironment('KOLKHOZ_SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'KOLKHOZ_SUPABASE_PUBLISHABLE_KEY',
  );
  static const authRedirectUrl = 'com.williamtheisen.kolkhoz://login-callback/';

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

class KolkhozSupabaseRuntime extends ChangeNotifier {
  KolkhozSupabaseRuntime._();

  static final instance = KolkhozSupabaseRuntime._();

  bool _started = false;
  bool _ready = false;
  Object? _error;
  Future<void>? _initialization;

  bool get isConfigured => KolkhozSupabaseConfig.isConfigured;
  bool get isReady => _ready;
  Object? get error => _error;

  SupabaseClient? get client {
    if (!_ready) {
      return null;
    }
    return Supabase.instance.client;
  }

  Future<void> start() {
    if (!isConfigured) {
      return Future<void>.value();
    }
    if (_started) {
      return _initialization ?? Future<void>.value();
    }
    _started = true;
    return _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Supabase.initialize(
        url: KolkhozSupabaseConfig.url,
        publishableKey: KolkhozSupabaseConfig.publishableKey,
      ).timeout(const Duration(seconds: 8));
      _ready = true;
      _error = null;
    } catch (error) {
      _ready = false;
      _error = error;
    } finally {
      notifyListeners();
    }
  }
}
