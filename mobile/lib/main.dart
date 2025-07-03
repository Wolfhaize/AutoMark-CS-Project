import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/answer_provider.dart';
import 'providers/result_provider.dart';
import 'screens/home_screen.dart';
import 'screens/upload_script_screen.dart';
import 'screens/answer_key_screen.dart';
import 'screens/result_screen.dart';

void main(){
  runApp(const AutoMarkApp());
}

class AutoMarkApp extends StatelessWidget{
  const AutoMarkApp({super.key});

  @override
  Widget build(BuildContext context){
    return MultiProvider(
      providers:[ChangeNotifierProvider(create:(_) => AnswerProvider()),
      ChangeNotifierProvider(create:(_) => ResultProvider()),],
      child:MaterialApp(
        title:'AutoMark',
        debugShowCheckedModeBanner: false,
        theme:ThemeData(primarySwatch:Colors.green,
        useMaterial3: true,),
        initialRoute:'/',
        routes:{
          '/':(context) => const HomeScreen(),
          '/upload':(context) => const AnswerKeyScreen(),
          '/result':(context) => const ResultScreen(),
        },
      ),
    );
  }
}
   