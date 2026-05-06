import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/chat_screen.dart';

/// Firebase를 초기화하고 앱을 시작하는 진입점.
///
/// [WidgetsFlutterBinding.ensureInitialized]로 Flutter 엔진을 초기화한 뒤,
/// Firebase 초기화를 완료하고 [ProviderScope]로 감싼 루트 위젯을 실행한다.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

/// 앱의 루트 위젯으로, Material 3 기반의 라이트/다크 테마를 정의한다.
///
/// 최신 ChatGPT(5.x) 톤을 따른다 — 흰 배경, monochrome 액센트, 옅은 회색 사용자 버블.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ChatGPT 5.x 라이트 톤
  static const _bgLight = Color(0xFFFFFFFF);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _userBubbleLight = Color(0xFFF4F4F4);
  static const _onSurfaceLight = Color(0xFF0D0D0D);
  static const _onSurfaceVariantLight = Color(0xFF5D5D5D);
  static const _outlineLight = Color(0xFFE5E5E5);
  static const _accentLight = Color(0xFF0D0D0D);

  // ChatGPT 5.x 다크 톤
  static const _bgDark = Color(0xFF212121);
  static const _surfaceDark = Color(0xFF212121);
  static const _userBubbleDark = Color(0xFF2F2F2F);
  static const _onSurfaceDark = Color(0xFFECECEC);
  static const _onSurfaceVariantDark = Color(0xFFB4B4B4);
  static const _outlineDark = Color(0xFF424242);
  static const _accentDark = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instructional Tutoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Apple SD Gothic Neo',
        fontFamilyFallback: const ['Malgun Gothic', 'Dotum', 'sans-serif'],
        scaffoldBackgroundColor: _bgLight,
        colorScheme: const ColorScheme.light(
          primary: _accentLight,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFEFEFEF),
          onPrimaryContainer: _onSurfaceLight,
          secondary: _onSurfaceVariantLight,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFEFEFEF),
          onSecondaryContainer: _onSurfaceLight,
          tertiary: _onSurfaceLight,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFEFEFEF),
          onTertiaryContainer: _onSurfaceLight,
          surface: _surfaceLight,
          onSurface: _onSurfaceLight,
          surfaceContainerLow: Color(0xFFFAFAFA),
          surfaceContainer: Color(0xFFF9F9F9),
          surfaceContainerHigh: _userBubbleLight,
          surfaceContainerHighest: Color(0xFFEDEDED),
          onSurfaceVariant: _onSurfaceVariantLight,
          outline: Color(0xFFC2C2C2),
          outlineVariant: _outlineLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgLight,
          foregroundColor: _onSurfaceLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Apple SD Gothic Neo',
        fontFamilyFallback: const ['Malgun Gothic', 'Dotum', 'sans-serif'],
        scaffoldBackgroundColor: _bgDark,
        colorScheme: const ColorScheme.dark(
          primary: _accentDark,
          onPrimary: _onSurfaceLight,
          primaryContainer: Color(0xFF333333),
          onPrimaryContainer: _onSurfaceDark,
          secondary: _onSurfaceVariantDark,
          onSecondary: _onSurfaceLight,
          secondaryContainer: Color(0xFF333333),
          onSecondaryContainer: _onSurfaceDark,
          tertiary: _onSurfaceDark,
          onTertiary: _onSurfaceLight,
          tertiaryContainer: Color(0xFF333333),
          onTertiaryContainer: _onSurfaceDark,
          surface: _surfaceDark,
          onSurface: _onSurfaceDark,
          surfaceContainerLow: Color(0xFF262626),
          surfaceContainer: Color(0xFF2A2A2A),
          surfaceContainerHigh: _userBubbleDark,
          surfaceContainerHighest: Color(0xFF383838),
          onSurfaceVariant: _onSurfaceVariantDark,
          outline: Color(0xFF6E6E6E),
          outlineVariant: _outlineDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgDark,
          foregroundColor: _onSurfaceDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
