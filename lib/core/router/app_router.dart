import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/stadiums/stadiums_screen.dart';
import '../../features/games/games_screen.dart';
import '../../features/teams/teams_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/reels/reels_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/tournaments/tournaments_screen.dart';
import '../api/token_storage.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final onboarding = ref.watch(onboardingDoneProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final status = auth.status;

      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      final onboardingDone = onboarding.asData?.value ?? true;
      final isPublic = loc == '/login' ||
          loc == '/register' ||
          loc == '/onboarding' ||
          loc == '/splash';

      if (status == AuthStatus.unauthenticated) {
        if (!onboardingDone && loc != '/onboarding') return '/onboarding';
        if (onboardingDone && (loc == '/onboarding' || loc == '/splash')) {
          return '/login';
        }
        if (onboardingDone && !isPublic) return '/login';
        return null;
      }

      if (loc == '/login' ||
          loc == '/register' ||
          loc == '/onboarding' ||
          loc == '/splash') {
        return '/app';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/app', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/games',
                builder: (_, __) => const GamesScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, __) => const CreateGameScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => GameDetailScreen(
                      gameId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/reels',
                builder: (_, __) => const ReelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Stack routes (not in bottom nav)
      GoRoute(
        path: '/app/stadiums',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StadiumsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => StadiumDetailScreen(
              stadiumId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/app/teams',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TeamsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const CreateTeamScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => TeamDetailScreen(
              teamId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/app/tournaments',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TournamentsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => TournamentDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/app/bookings',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BookingsScreen(),
      ),
      GoRoute(
        path: '/app/users/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => UserProfileScreen(
          userId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(image: AssetImage('assets/logo.jpg'), height: 88),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
