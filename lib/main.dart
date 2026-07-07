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
/// Google Gemini 웹 앱 톤을 따른다 — 흰 배경, Google Blue 액센트,
/// 회청색(#F0F4F9) 사용자 버블, 라이트 블루 전송 버튼.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Gemini 라이트 톤 (Google Material 3 팔레트)
  static const _bgLight = Color(0xFFFFFFFF);
  static const _onSurfaceLight = Color(0xFF1F1F1F);
  static const _onSurfaceVariantLight = Color(0xFF575B5F);
  static const _userBubbleLight = Color(0xFFF0F4F9);

  // Gemini 다크 톤
  static const _bgDark = Color(0xFF131314);
  static const _onSurfaceDark = Color(0xFFE3E3E3);
  static const _onSurfaceVariantDark = Color(0xFFC4C7C5);
  static const _userBubbleDark = Color(0xFF333537);

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
          // Google Blue 계열
          primary: Color(0xFF0B57D0),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFD3E3FD),
          onPrimaryContainer: Color(0xFF041E49),
          secondary: Color(0xFF00639B),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFC2E7FF), // 전송 버튼 (라이트 블루)
          onSecondaryContainer: Color(0xFF001D35),
          tertiary: Color(0xFF146C2E),
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFC4EED0),
          onTertiaryContainer: Color(0xFF072711),
          surface: _bgLight,
          onSurface: _onSurfaceLight,
          surfaceContainerLow: Color(0xFFF8FAFD),
          surfaceContainer: Color(0xFFF0F4F9),
          surfaceContainerHigh: _userBubbleLight, // 사용자 버블
          surfaceContainerHighest: Color(0xFFE9EEF6),
          onSurfaceVariant: _onSurfaceVariantLight,
          outline: Color(0xFFC4C7C5),
          outlineVariant: Color(0xFFE1E3E1),
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
          primary: Color(0xFFA8C7FA),
          onPrimary: Color(0xFF062E6F),
          primaryContainer: Color(0xFF0842A0),
          onPrimaryContainer: Color(0xFFD3E3FD),
          secondary: Color(0xFF7FCFFF),
          onSecondary: Color(0xFF003355),
          secondaryContainer: Color(0xFF004A77), // 전송 버튼
          onSecondaryContainer: Color(0xFFC2E7FF),
          tertiary: Color(0xFF6DD58C),
          onTertiary: Color(0xFF0A3818),
          tertiaryContainer: Color(0xFF0F5223),
          onTertiaryContainer: Color(0xFFC4EED0),
          surface: _bgDark,
          onSurface: _onSurfaceDark,
          surfaceContainerLow: Color(0xFF1B1B1C),
          surfaceContainer: Color(0xFF1E1F20),
          surfaceContainerHigh: _userBubbleDark, // 사용자 버블
          surfaceContainerHighest: Color(0xFF444746),
          onSurfaceVariant: _onSurfaceVariantDark,
          outline: Color(0xFF8E918F),
          outlineVariant: Color(0xFF444746),
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
