import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onco_repurpose_ai/services/network/network_consent.dart';

void main() {
  late Directory tempDir;
  late File storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onco_consent_test');
    storage = File('${tempDir.path}${Platform.pathSeparator}consent');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('denies external requests before anything is loaded', () {
    final consent = NetworkConsent(storageOverride: storage);
    expect(consent.allowExternalRequests, isFalse);
    expect(consent.isLoaded, isFalse);
  });

  test('stays denied when no preference has been stored', () async {
    final consent = NetworkConsent(storageOverride: storage);
    await consent.load();

    expect(consent.isLoaded, isTrue);
    expect(consent.allowExternalRequests, isFalse,
        reason: 'external lookups must be opt-in');
  });

  test('persists a granted choice across instances', () async {
    final first = NetworkConsent(storageOverride: storage);
    await first.load();
    await first.setAllowed(true);

    final second = NetworkConsent(storageOverride: storage);
    await second.load();
    expect(second.allowExternalRequests, isTrue);
  });

  test('persists a revoked choice across instances', () async {
    final first = NetworkConsent(storageOverride: storage);
    await first.load();
    await first.setAllowed(true);
    await first.setAllowed(false);

    final second = NetworkConsent(storageOverride: storage);
    await second.load();
    expect(second.allowExternalRequests, isFalse);
  });

  test('notifies listeners when the choice changes', () async {
    final consent = NetworkConsent(storageOverride: storage);
    await consent.load();

    var notifications = 0;
    consent.addListener(() => notifications++);

    await consent.setAllowed(true);
    expect(notifications, 1);

    // Setting the same value again must not churn listeners.
    await consent.setAllowed(true);
    expect(notifications, 1);

    await consent.setAllowed(false);
    expect(notifications, 2);
  });

  test('notifies listeners once loading finishes', () async {
    final consent = NetworkConsent(storageOverride: storage);
    var notified = false;
    consent.addListener(() => notified = true);

    await consent.load();
    expect(notified, isTrue);
  });

  test('fails closed on an unreadable preference', () async {
    // A directory where a file is expected makes the read throw. Consent must
    // never default to granted on error.
    final blocked =
        Directory('${tempDir.path}${Platform.pathSeparator}blocked');
    await blocked.create();
    final consent =
        NetworkConsent(storageOverride: File(blocked.path));

    await consent.load();
    expect(consent.allowExternalRequests, isFalse);
    expect(consent.isLoaded, isTrue);
  });

  test('treats unrecognised stored content as denied', () async {
    await storage.writeAsString('maybe');
    final consent = NetworkConsent(storageOverride: storage);

    await consent.load();
    expect(consent.allowExternalRequests, isFalse);
  });

  test('applies a granted choice for the session even if saving fails',
      () async {
    final blocked =
        Directory('${tempDir.path}${Platform.pathSeparator}blocked2');
    await blocked.create();
    final consent =
        NetworkConsent(storageOverride: File(blocked.path));
    await consent.load();

    await expectLater(consent.setAllowed(true), completes);
    expect(consent.allowExternalRequests, isTrue);
  });
}
