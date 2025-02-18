import 'package:educode/features/courses/data/services/activity_service.dart';
import 'package:educode/features/courses/data/services/enrollment_service.dart';
import 'package:educode/features/courses/data/services/submission_service.dart';
import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:educode/features/courses/presentation/views/student_activity_submission_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/courses/presentation/providers/subjects_provider.dart';
import 'features/courses/data/services/subjects_service.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/courses/presentation/pages/home_page.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(context),
        ),
        ChangeNotifierProvider(
          create: (context) => SubjectsProvider(SubjectsService()),
        ),
        ChangeNotifierProvider(
          create: (context) => EnrollmentProvider(EnrollmentService()),
        ),
        ChangeNotifierProvider(
          create: (context) => SubmissionProvider(SubmissionService()),
        ),
        ChangeNotifierProvider(
          create: (context) => ActivityProvider(ActivityService()),
        ),
      ],  
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EduCode',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
          '/student-activity-submission': (context) => const StudentActivitySubmissionPage(),
        },
      ),
    );
  }
}
