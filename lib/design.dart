import 'package:flutter/material.dart';

const primeRed = Color(0xffd62828);
const primeInk = Color(0xff17202f);
const primeMuted = Color(0xff667085);
const primeLine = Color(0xffe6e9ef);
const primeBackground = Color(0xfff6f7fa);

ThemeData temaAutoPrime() {
  final borda = OutlineInputBorder(borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: primeLine));
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(primary: primeRed, onPrimary: Colors.white,
      secondary: primeInk, onSecondary: Colors.white, surface: Colors.white,
      onSurface: primeInk, error: Color(0xffb42318)),
    scaffoldBackgroundColor: primeBackground,
    dividerColor: primeLine,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: primeInk,
      surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0,
      centerTitle: false, titleTextStyle: TextStyle(color: primeInk, fontSize: 20,
        fontWeight: FontWeight.w700)),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xfffafbfc),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: borda, enabledBorder: borda,
      focusedBorder: borda.copyWith(borderSide: const BorderSide(color: primeRed, width: 1.5)),
      hintStyle: const TextStyle(color: primeMuted, fontSize: 14),
      labelStyle: const TextStyle(color: primeMuted)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: primeRed, foregroundColor: Colors.white, elevation: 0,
      minimumSize: const Size(48, 50), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: primeInk, side: const BorderSide(color: primeLine),
      minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      minimumSize: const Size(48, 44), foregroundColor: primeRed,
      textStyle: const TextStyle(fontWeight: FontWeight.w600))),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, indicatorColor: Color(0xffffe8e8), height: 72),
    chipTheme: ChipThemeData(backgroundColor: Colors.white, selectedColor: const Color(0xffffe8e8),
      side: const BorderSide(color: primeLine), padding: const EdgeInsets.all(9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating,
      backgroundColor: primeInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: primeInk),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: primeInk)),
  );
}

class PrimeCard extends StatelessWidget {
  final Widget child;
  final Clip clipBehavior;
  final EdgeInsetsGeometry? margin;
  const PrimeCard({super.key, required this.child, this.clipBehavior = Clip.none, this.margin});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, surfaceTintColor: Colors.transparent,
    elevation: 0, margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
    clipBehavior: clipBehavior,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: primeLine)), child: child);
}

class PrimeBrand extends StatelessWidget {
  final bool claro;
  const PrimeBrand({super.key, this.claro = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 40, height: 40,
      decoration: BoxDecoration(color: primeRed, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.directions_car_filled_outlined, color: Colors.white, size: 24)),
    const SizedBox(width: 10),
    Text('AutoPrime', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800,
      letterSpacing: -0.7, color: claro ? Colors.white : primeInk)),
  ]);
}

class PageTitle extends StatelessWidget {
  final String titulo, subtitulo;
  const PageTitle(this.titulo, this.subtitulo, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: MediaQuery.sizeOf(context).width < 600 ? 28 : 34,
        fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.15)),
      const SizedBox(height: 10),
      Text(subtitulo, style: const TextStyle(color: primeMuted, height: 1.6)),
    ]));
}

class AuthLayout extends StatelessWidget {
  final Widget child;
  const AuthLayout({super.key, required this.child});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final grande = constraints.maxWidth >= 900;
    final painel = Container(padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft,
        end: Alignment.bottomRight, colors: [primeInk, Color(0xff29374c)])),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PrimeBrand(claro: true), Spacer(),
        Text('O cuidado com seu\ncarro começa aqui.', style: TextStyle(color: Colors.white,
          fontSize: 46, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -1.5)),
        SizedBox(height: 24),
        Text('Peças e acessórios em um só lugar.\nExplore o catálogo no seu ritmo.',
          style: TextStyle(color: Color(0xffc4ccd8), fontSize: 17, height: 1.7)),
        SizedBox(height: 40),
        Divider(color: Color(0xff48556a)), SizedBox(height: 16),
        Text('CATÁLOGO  /  CARRINHO  /  SEU PERFIL',
          style: TextStyle(color: Color(0xffc4ccd8), fontSize: 11, letterSpacing: 2)),
      ]));
    final conteudo = Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child)));
    return grande ? Row(children: [Expanded(child: painel), Expanded(child: conteudo)]) : conteudo;
  });
}
