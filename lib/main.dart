import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';
import 'package:zensort/features/auth/presentation/auth_gate.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/data/repositories/youtube_repository_impl.dart';
import 'package:zensort/features/youtube/data/services/youtube_api_service.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/firebase_options_dev.dart' as dev;
import 'package:zensort/firebase_options.dart' as prod;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zensort/router.dart';
import 'package:zensort/theme.dart';
import 'package:cloud_functions/cloud_functions.dart';

// const bool useEmulator = true; // Disabled as per user request

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR');
  final FirebaseOptions firebaseOptions;

  switch (flavor) {
    case 'dev':
      firebaseOptions = dev.DefaultFirebaseOptions.currentPlatform;
      break;
    case 'prod':
    default:
      firebaseOptions = prod.DefaultFirebaseOptions.currentPlatform;
      break;
  }

  await Firebase.initializeApp(options: firebaseOptions);

  // if (useEmulator && kIsWeb) { // Disabled as per user request
  //   try {
  //     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  //     FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  //     FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  //   } catch (e) {
  //     print('Error using emulators: $e');
  //   }
  // }
  runApp(const ZenSortApp());
}

class ZenSortApp extends StatelessWidget {
  const ZenSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepositoryImpl(
            FirebaseAuth.instance,
            FirebaseFirestore.instance,
          ),
        ),
        RepositoryProvider<YouTubeRepository>(
          create: (context) => YouTubeRepositoryImpl(
            YouTubeApiService(
              FirebaseFunctions.instance,
              FirebaseAuth.instance,
            ),
            FirebaseFirestore.instance,
            FirebaseAuth.instance,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(context.read<AuthRepository>()),
          ),
          BlocProvider<YouTubeBloc>(
            create: (context) => YouTubeBloc(context.read<YouTubeRepository>()),
          ),
        ],
        child: MaterialApp.router(
          title: 'ZenSort',
          theme: getLightTheme(),
          darkTheme: getDarkTheme(),
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
