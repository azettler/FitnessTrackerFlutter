import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/calendar/calendar_screen.dart';
import '../screens/calendar/day_detail_screen.dart';
import '../screens/exercises/exercise_detail_screen.dart';
import '../screens/exercises/exercise_form_screen.dart';
import '../screens/exercises/exercises_screen.dart';
import '../screens/goals/goal_form_screen.dart';
import '../screens/goals/goals_screen.dart';
import '../screens/progress/photo_viewer_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/settings_screen.dart';
import '../screens/workouts/exercise_picker_screen.dart';
import '../screens/workouts/schedule_form_screen.dart';
import '../screens/workouts/workout_instance_screen.dart';
import '../screens/workouts/workout_plan_detail_screen.dart';
import '../screens/workouts/workout_plan_form_screen.dart';
import '../screens/workouts/workouts_screen.dart';
import '../widgets/common/scaffold_with_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _calendarKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _workoutsKey = GlobalKey<NavigatorState>(debugLabel: 'workouts');
final _exercisesKey = GlobalKey<NavigatorState>(debugLabel: 'exercises');
final _goalsKey = GlobalKey<NavigatorState>(debugLabel: 'goals');
final _reportsKey = GlobalKey<NavigatorState>(debugLabel: 'reports');
final _progressKey = GlobalKey<NavigatorState>(debugLabel: 'progress');

PhotoViewerScreen _photoViewer(GoRouterState s) {
  final extra = s.extra as Map<String, dynamic>;
  return PhotoViewerScreen(
    photos: (extra['photos'] as List).cast<Map<String, dynamic>>(),
    initialIndex: extra['initialIndex'] as int,
  );
}

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/calendar',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ScaffoldWithNav(shell: shell),
      branches: [
        // ── Calendar ──────────────────────────────────────────────────────────
        StatefulShellBranch(navigatorKey: _calendarKey, routes: [
          GoRoute(
            path: '/calendar',
            builder: (ctx, s) => const CalendarScreen(),
            routes: [
              GoRoute(
                path: 'day/:date',
                builder: (_, s) => DayDetailScreen(date: s.pathParameters['date']!),
                routes: [
                  GoRoute(
                    path: 'instance/:id',
                    builder: (_, s) => WorkoutInstanceScreen(
                      instanceId: int.parse(s.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'photo-viewer',
                    builder: (_, s) => _photoViewer(s),
                  ),
                ],
              ),
            ],
          ),
        ]),

        // ── Workouts ──────────────────────────────────────────────────────────
        StatefulShellBranch(navigatorKey: _workoutsKey, routes: [
          GoRoute(
            path: '/workouts',
            builder: (ctx, s) => const WorkoutsScreen(),
            routes: [
              // 'new' must precede ':id' to avoid matching 'new' as an ID
              GoRoute(
                path: 'plan/new',
                builder: (ctx, s) => const WorkoutPlanFormScreen(),
              ),
              GoRoute(
                path: 'plan/:id',
                builder: (_, s) => WorkoutPlanDetailScreen(
                  planId: int.parse(s.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'form',
                    builder: (_, s) => WorkoutPlanFormScreen(
                      planId: int.tryParse(s.pathParameters['id'] ?? ''),
                    ),
                  ),
                  GoRoute(
                    path: 'schedule/form',
                    builder: (_, s) {
                      final scheduleId = (s.extra as Map<String, dynamic>?)?['scheduleId'] as int?;
                      return ScheduleFormScreen(
                        planId: int.parse(s.pathParameters['id']!),
                        scheduleId: scheduleId,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'exercise-picker',
                builder: (_, s) => ExercisePickerScreen(
                  extra: s.extra as Map<String, dynamic>,
                ),
              ),
              GoRoute(
                path: 'instance/:id',
                builder: (_, s) => WorkoutInstanceScreen(
                  instanceId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ]),

        // ── Exercises ─────────────────────────────────────────────────────────
        StatefulShellBranch(navigatorKey: _exercisesKey, routes: [
          GoRoute(
            path: '/exercises',
            builder: (ctx, s) => const ExercisesScreen(),
            routes: [
              // 'new' before ':id'
              GoRoute(
                path: 'new',
                builder: (ctx, s) => const ExerciseFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) => ExerciseDetailScreen(
                  exerciseId: int.parse(s.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, s) => ExerciseFormScreen(
                      exerciseId: int.parse(s.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]),

        // ── Goals ─────────────────────────────────────────────────────────────
        StatefulShellBranch(navigatorKey: _goalsKey, routes: [
          GoRoute(
            path: '/goals',
            builder: (ctx, s) => const GoalsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (ctx, s) => const GoalFormScreen(),
              ),
            ],
          ),
        ]),

        // ── Reports ───────────────────────────────────────────────────────────
        StatefulShellBranch(navigatorKey: _reportsKey, routes: [
          GoRoute(
            path: '/reports',
            builder: (ctx, s) => const ReportsScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (ctx, s) => const SettingsScreen(),
              ),
            ],
          ),
        ]),

        // ── Progress ──────────────────────────────────────────────────────────
        StatefulShellBranch(navigatorKey: _progressKey, routes: [
          GoRoute(
            path: '/progress',
            builder: (ctx, s) => const ProgressScreen(),
            routes: [
              GoRoute(
                path: 'viewer',
                builder: (_, s) => _photoViewer(s),
              ),
            ],
          ),
        ]),
      ],
    ),
  ],
);
