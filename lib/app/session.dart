import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import '../domain/book.dart';

/// Vidya in Brahma's terms: the app's id, name and Android package.
const vidyaIdentity = AppIdentity(
  id: 'vidya',
  name: 'Vidya',
  androidPackage: 'dev.brahma.vidya',
  releases: 'sudharamachandranrajeev/vidya-learning-manager',
);

/// Everything a running app needs: keys, the encrypted database and the
/// learning book on top of it. Opened once at start-up.
class AppSession extends CoreSession {
  AppSession(super.keys, super.store, this.book, {super.deviceName});

  final LearningBook book;

  @override
  AppDatabase get db => store.db as AppDatabase;

  static Future<AppSession> open(KeyVault keys) => CoreSession.open(
    vidyaIdentity,
    keys,
    openDatabase: AppDatabase.open,
    build: (store, deviceName) => AppSession(keys, store, LearningBook(store), deviceName: deviceName),
  );
}
