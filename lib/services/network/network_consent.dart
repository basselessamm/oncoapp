import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether the user has allowed the app to contact external services, and how
/// much of the cache is currently stored.
///
/// External lookups are off by default. A gene list from an unpublished study
/// reveals what a researcher is working on before they have published it, so
/// consent is explicit rather than assumed, and the whole app remains fully
/// functional with it off - every existing feature runs against the bundled
/// database.
class NetworkConsent extends ChangeNotifier {
  NetworkConsent({File? storageOverride}) : _storageOverride = storageOverride;

  static const String _fileName = 'network_consent';

  final File? _storageOverride;

  bool _allowExternalRequests = false;
  bool _loaded = false;

  /// Whether outbound requests are permitted. Defaults to `false`.
  bool get allowExternalRequests => _allowExternalRequests;

  /// Whether the stored preference has been read from disk yet.
  ///
  /// The UI shows the toggle as off until this is `true`, so a slow disk read
  /// cannot briefly present consent as granted.
  bool get isLoaded => _loaded;

  Future<File> _file() async {
    final override = _storageOverride;
    if (override != null) return override;

    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = await getApplicationDocumentsDirectory();
    }
    if (!await base.exists()) await base.create(recursive: true);
    return File(p.join(base.path, _fileName));
  }

  /// Reads the stored preference. Absent or unreadable state means denied.
  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        _allowExternalRequests = (await file.readAsString()).trim() == 'granted';
      }
    } catch (error) {
      // Fail closed: an unreadable preference must not enable network access.
      debugPrint('Consent load failed, defaulting to denied: $error');
      _allowExternalRequests = false;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Records the user's choice.
  Future<void> setAllowed(bool allowed) async {
    if (_allowExternalRequests == allowed) return;
    _allowExternalRequests = allowed;
    notifyListeners();

    try {
      final file = await _file();
      await file.writeAsString(allowed ? 'granted' : 'denied', flush: true);
    } catch (error) {
      // The in-memory value already applies for this session; it will simply
      // revert to denied on next launch.
      debugPrint('Consent save failed: $error');
    }
  }
}
