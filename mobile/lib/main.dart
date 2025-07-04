import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/answer_provider.dart';
import 'providers/result_provider.dart';
/*import 'screens/home_screen.dart';
import 'screens/upload_script_screen.dart';
import 'screens/answer_key_screen.dart';
import 'screens/result_screen.dart';*/
import 'screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Initialize Firebase before the app starts
  await Firebase.initializeApp(
    options:DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AutoMarkApp());
}

class AutoMarkApp extends StatelessWidget {
  const AutoMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnswerProvider()),
        ChangeNotifierProvider(create: (_) => ResultProvider()),
      ],
      child: MaterialApp(
        title: 'AutoMark',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        initialRoute: '/signup', // Use this for now to test SignUp screen
        routes: {
          '/signup': (context) => const SignUpScreen(),
          // '/': (context) => const HomeScreen(),
          // '/upload': (context) => const AnswerKeyScreen(),
          // '/result': (context) => const ResultScreen(),
        },
      ),
    );
  }
}
   