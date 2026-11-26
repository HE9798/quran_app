import 'package:flutter_test/flutter_test.dart';
import 'package:quran/features/khatma/data/khatma_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KhatmaStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = KhatmaStore.instance;
    await store.load();
    await store.reset();
  });

  test('a new khatma continues from page 1', () async {
    await store.start(30);
    expect(store.nextPage, 1);
  });

  test('reading in the reader moves "Continue" to that page', () async {
    await store.start(30);
    await store.readUpTo(15);
    expect(store.currentPage, 14);
    expect(store.nextPage, 15);
  });

  test('going back to earlier pages does not lose progress', () async {
    await store.start(30);
    await store.readUpTo(40);
    await store.readUpTo(10);
    expect(store.nextPage, 40);
  });

  test('progress survives an app restart', () async {
    await store.start(30);
    await store.readUpTo(77);
    await store.load(); // reads back from SharedPreferences
    expect(store.active, isTrue);
    expect(store.nextPage, 77);
  });

  test('reports when today\'s portion becomes done, only once', () async {
    await store.start(30); // day 1 = pages 1..21
    expect(await store.readUpTo(10), isFalse);
    expect(await store.readUpTo(22), isTrue); // pages 1..21 finished
    expect(await store.readUpTo(25), isFalse);
  });

  test('reaching the last page never completes the khatma by itself', () async {
    await store.start(30);
    await store.readUpTo(604);
    expect(store.active, isTrue);
    expect(store.currentPage, 603);
    expect(store.completedCount, 0);
  });

  test('does nothing when no khatma is active', () async {
    expect(await store.readUpTo(50), isFalse);
    expect(store.currentPage, 0);
  });
}
