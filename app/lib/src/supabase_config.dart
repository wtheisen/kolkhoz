import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Transitional access to an existing Supabase Auth session.
///
/// Profile data never flows through this client. Remove this bridge after the
/// installed legacy population has exchanged its session for a Kolkhoz token.
class KolkhozSupabaseConfig {
  const KolkhozSupabaseConfig._();

  static const url = String.fromEnvironment('KOLKHOZ_SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'KOLKHOZ_SUPABASE_PUBLISHABLE_KEY',
  );

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

  SupabaseClient? get client => _ready ? Supabase.instance.client : null;

  Future<void> start() {
    if (!isConfigured) return Future<void>.value();
    if (_started) return _initialization ?? Future<void>.value();
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
