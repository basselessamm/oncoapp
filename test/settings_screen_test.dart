import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/screens/settings_screen.dart';
import 'package:onco_repurpose_ai/services/network/network_consent.dart';
import 'package:onco_repurpose_ai/services/network/response_cache.dart';
import 'package:onco_repurpose_ai/widgets/evidence_widgets.dart';
import 'package:provider/provider.dart';

/// In-memory cache stand-in.
///
/// `testWidgets` runs inside a fake-async zone where real file I/O never
/// completes, so the widget tests use fakes and the real disk behaviour is
/// covered by `response_cache_test.dart`.
class _FakeCache extends ResponseCache {
  _FakeCache({this.entries = 0, this.bytes = 0});

  int entries;
  int bytes;
  int clearCount = 0;

  @override
  Future<CacheStats> stats() async =>
      CacheStats(entries: entries, bytes: bytes);

  @override
  Future<void> clear() async {
    clearCount++;
    entries = 0;
    bytes = 0;
  }
}

/// Consent stand-in that records choices without touching disk.
class _FakeConsent extends NetworkConsent {
  _FakeConsent({bool allowed = false, bool loaded = true})
      : _allowed = allowed,
        _loaded = loaded;

  bool _allowed;
  final bool _loaded;

  @override
  bool get allowExternalRequests => _allowed;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> setAllowed(bool allowed) async {
    if (_allowed == allowed) return;
    _allowed = allowed;
    notifyListeners();
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _FakeCache cache,
    required NetworkConsent consent,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkConsent>.value(value: consent),
          Provider<ResponseCache>.value(value: cache),
        ],
        child: MaterialApp(home: SettingsScreen(cache: cache)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('consent control', () {
    testWidgets('shows external lookups off by default', (tester) async {
      await pump(tester, cache: _FakeCache(), consent: _FakeConsent());

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Allow external lookups'),
      );
      expect(toggle.value, isFalse);
      expect(find.text('Off. Nothing leaves this device.'), findsOneWidget);
    });

    testWidgets('states exactly what would be transmitted', (tester) async {
      await pump(tester, cache: _FakeCache(), consent: _FakeConsent());

      expect(find.textContaining('the gene symbols in your query'),
          findsOneWidget);
      expect(find.textContaining('no fold changes'), findsOneWidget);
      expect(find.textContaining('no file contents'), findsOneWidget);
    });

    testWidgets('states that every feature works with lookups off',
        (tester) async {
      await pump(tester, cache: _FakeCache(), consent: _FakeConsent());

      expect(
        find.textContaining('everything the app does today'),
        findsOneWidget,
      );
    });

    testWidgets('explains the research risk rather than just asking',
        (tester) async {
      await pump(tester, cache: _FakeCache(), consent: _FakeConsent());

      expect(
        find.textContaining(
            'unpublished study reveals what you are working on'),
        findsOneWidget,
      );
    });

    testWidgets('enabling the toggle records the choice', (tester) async {
      final consent = _FakeConsent();
      await pump(tester, cache: _FakeCache(), consent: consent);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Allow external lookups'),
      );
      await tester.pumpAndSettle();

      expect(consent.allowExternalRequests, isTrue);
      expect(
        find.textContaining('Gene symbols you query are sent'),
        findsOneWidget,
      );
    });

    testWidgets('disables the toggle until the stored choice has loaded',
        (tester) async {
      await pump(
        tester,
        cache: _FakeCache(),
        consent: _FakeConsent(loaded: false),
      );

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Allow external lookups'),
      );
      // A slow disk read must not briefly present consent as grantable.
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isFalse);
    });
  });

  group('cache management', () {
    testWidgets('reports an empty cache and disables clearing', (tester) async {
      await pump(tester, cache: _FakeCache(), consent: _FakeConsent());

      expect(find.text('No cached responses'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Clear cached responses'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('reports the number and size of cached responses',
        (tester) async {
      await pump(
        tester,
        cache: _FakeCache(entries: 2, bytes: 4096),
        consent: _FakeConsent(),
      );

      expect(find.textContaining('2 cached responses'), findsOneWidget);
      expect(find.textContaining('4 KB'), findsOneWidget);
    });

    testWidgets('uses the singular form for one entry', (tester) async {
      await pump(
        tester,
        cache: _FakeCache(entries: 1, bytes: 512),
        consent: _FakeConsent(),
      );

      expect(find.textContaining('1 cached response  -'), findsOneWidget);
    });

    testWidgets('explains the retention window and offline labelling',
        (tester) async {
      await pump(tester, cache: _FakeCache(), consent: _FakeConsent());

      expect(find.textContaining('up to 30 days'), findsOneWidget);
      expect(
          find.textContaining('labelled as an offline copy'), findsOneWidget);
    });

    testWidgets('clearing removes stored responses', (tester) async {
      final cache = _FakeCache(entries: 3, bytes: 8192);
      await pump(tester, cache: cache, consent: _FakeConsent());

      final button =
          find.widgetWithText(OutlinedButton, 'Clear cached responses');
      // The consent card is tall enough to push the button below the test
      // viewport, so a bare tap would miss it.
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(cache.clearCount, 1);
      expect(find.text('Cached responses cleared'), findsOneWidget);
      expect(find.text('No cached responses'), findsOneWidget);
    });
  });

  group('offline banner', () {
    testWidgets('describes the age of an offline copy', (tester) async {
      final retrieved = DateTime.now().subtract(const Duration(hours: 3));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OfflineDataBanner(retrievedAt: retrieved)),
        ),
      );

      expect(find.textContaining('Offline copy from 3 h ago'), findsOneWidget);
      expect(find.textContaining('may be out of date'), findsOneWidget);
    });

    testWidgets('offers a retry action when one is provided', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineDataBanner(
              retrievedAt: DateTime.now(),
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    test('describes ages at each granularity', () {
      final now = DateTime.now();
      expect(
        OfflineDataBanner.describeAge(now.subtract(const Duration(minutes: 5))),
        'from 5 min ago',
      );
      expect(
        OfflineDataBanner.describeAge(now.subtract(const Duration(hours: 8))),
        'from 8 h ago',
      );
      expect(
        OfflineDataBanner.describeAge(now.subtract(const Duration(days: 1))),
        'from yesterday',
      );
      expect(
        OfflineDataBanner.describeAge(now.subtract(const Duration(days: 9))),
        'from 9 days ago',
      );
      expect(OfflineDataBanner.describeAge(null), 'from an earlier session');
    });
  });
}
