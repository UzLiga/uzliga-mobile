import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/stadiums/stadiums_map_screen.dart';
import '../../features/stadiums/stadiums_screen.dart';
import '../../features/games/games_screen.dart';
import '../../features/battles/battles_screen.dart';
import '../../features/teams/teams_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/reels/reels_screen.dart';
import '../../features/reels/my_reels_screen.dart';
import '../../features/reels/hashtag_feed_screen.dart';
import '../../features/reels/clip_composer_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/tournaments/tournaments_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/premium/premium_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../features/free_agents/free_agents_screen.dart';
import '../api/token_storage.dart';
import '../analytics.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // IMPORTANT: do not watch auth here — remounts entire app shell on every refreshMe()
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final onboarding = ref.read(onboardingDoneProvider);
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
            path: 'map',
            builder: (_, __) => const StadiumsMapScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => StadiumDetailScreen(
              stadiumId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/app/map',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const StadiumsMapScreen(),
      ),
      GoRoute(
        path: '/app/battles',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const BattlesScreen(),
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
            path: 'join',
            builder: (_, state) => TeamJoinScreen(
              code: state.uri.queryParameters['code'],
            ),
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
        path: '/app/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/app/wallet',
        parentNavigatorKey: _rootKey,
        builder: (_, __) {
          Analytics.log('open_wallet');
          return const WalletScreen();
        },
      ),
      GoRoute(
        path: '/app/premium',
        parentNavigatorKey: _rootKey,
        builder: (_, __) {
          Analytics.log('open_premium');
          return const PremiumPaywallScreen();
        },
      ),
      GoRoute(
        path: '/app/free-agents',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const FreeAgentsScreen(),
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
        path: '/app/my-reels',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const MyReelsManageScreen(),
      ),
      GoRoute(
        path: '/app/clip-composer',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ClipComposerScreen(),
      ),
      GoRoute(
        path: '/app/hashtag/:tag',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => HashtagFeedScreen(
          tag: state.pathParameters['tag']!,
        ),
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
