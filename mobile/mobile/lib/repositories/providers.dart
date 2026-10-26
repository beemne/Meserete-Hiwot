import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../services/sync_service.dart';
import 'admin_repository.dart';
import 'auth_repository.dart';
import 'content_repository.dart';
import 'library_repository.dart';
import 'profession_repository.dart';
import 'project_repository.dart';
import 'stage_repository.dart';
import 'superapp_repositories.dart';
import 'user_repositories.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(secureStoreProvider)));
final contentRepositoryProvider = Provider((ref) => ContentRepository(ref.watch(apiClientProvider), ref.watch(localDbProvider)));
final programRepositoryProvider = Provider((ref) => ProgramRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(apiClientProvider)));
final borrowingRepositoryProvider = Provider((ref) => BorrowingRepository(ref.watch(apiClientProvider)));
final accountRepositoryProvider = Provider((ref) => AccountRepository(ref.watch(apiClientProvider), ref.watch(localPrefsProvider)));
final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));
final eduRepositoryProvider = Provider((ref) => EduRepository(ref.watch(apiClientProvider)));
final orgRepositoryProvider = Provider((ref) => OrgRepository(ref.watch(apiClientProvider)));
final choirRepositoryProvider = Provider((ref) => ChoirRepository(ref.watch(apiClientProvider)));
final stageRepositoryProvider = Provider((ref) => StageRepository(ref.watch(apiClientProvider)));
final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(apiClientProvider)));
final projectRepositoryProvider = Provider((ref) => ProjectRepository(ref.watch(apiClientProvider)));
final libraryRepositoryProvider = Provider((ref) => LibraryRepository(ref.watch(apiClientProvider), ref.watch(syncServiceProvider)));
final professionRepositoryProvider = Provider((ref) => ProfessionRepository(ref.watch(apiClientProvider)));
