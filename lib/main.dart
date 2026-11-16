import 'package:flutter/material.dart';
import 'login.dart';
import 'design.dart';

void main() => runApp(const AutoPrimeApp());

class AutoPrimeApp extends StatelessWidget {
  const AutoPrimeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'AutoPrime',
    theme: temaAutoPrime(), home: const LoginPage());
}
