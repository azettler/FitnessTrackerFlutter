import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/calendar/calendar_screen.dart';
import '../screens/calendar/day_detail_screen.dart';
import '../screens/calendar/workout_instance_screen.dart';
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
import '../screens/workouts/workout_instance_screen.dart' as workouts;
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

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/calendar',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(navigatorKey: _calendarKey, routes: [
          GoRoute(
            path: '/calendar',
            builder: (_, __) => const CalendarScreen(),
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
                    builder: (_, s) => PhotoViewerScreen(
                      photos: s.extra as List<Map<String, dynamic>>,
                      initialIndex: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(navigatorKey: _workoutsKey, routes: [
          GoRoute(
            path: '/workouts',
            builder: (_, __) => const WorkoutsScreen(),
            routes: [
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
                    builder: (_, s) => ScheduleFormScreen(
                      planId: int.parse(s.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'plan/new',
                builder: (_, __) => const WorkoutPlanFormScreen(),
              ),
              GoRoute(
                path: 'exercise-picker',
                builder: (_, s) => ExercisePickerScreen(
                  extra: s.extra as Map<String, dynamic>,
                ),
              ),
              GoRoute(
                path: 'instance/:id',
                builder: (_, s) => workouts.WorkoutInstanceScreen(
                  instanceId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(navigatorKey: _exercisesKey, routes: [
          GoRoute(
            path: '/exercises',
            builder: (_, __) => const ExercisesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => ExerciseDetailScreen(
                  exerciseId: int.parse(s.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: 'new',
                builder: (_, __) => const ExerciseFormScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(navigatorKey: _goalsKey, routes: [
          GoRoute(
            path: '/goals',
            builder: (_, __) => const GoalsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const GoalFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (_, s) => GoalFormScreen(
                  goalId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(navigatorKey: _reportsKey, routes: [
          GoRoute(
            path: '/reports',
            builder: (_, __) => const ReportsScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(navigatorKey: _progressKey, routes: [
          GoRoute(
            path: '/progress',
            builder: (_, __) => const ProgressScreen(),
            routes: [
              GoRoute(
                path: 'viewer',
                builder: (_, s) {
                  final extra = s.extra as Map<String, dynamic>;
                  return PhotoViewerScreen(
                    photos: extra['photos'] as List<Map<String, dynamic>>,
                    initialIndex: extra['initialIndex'] as int,
                  );
                },
              ),
            ],
          ),
        ]),
      ],
    ),
  ],
);
