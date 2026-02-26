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
/// [ChatScreen]을 홈 화면으로 설정하고, [colorScheme]을 통해
/// 앱 전체의 색상 테마를 일관되게 관리한다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const chatBg = Color(0xFFF7F7F8);
    const sidebarBg = Color(0xFF171717);

    return MaterialApp(
      title: 'Instructional Tutoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Apple SD Gothic Neo',
        fontFamilyFallback: const ['Malgun Gothic', 'Dotum', 'sans-serif'],
        scaffoldBackgroundColor: chatBg,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF10A37F),
          onPrimary: Colors.white,
          surface: chatBg,
          onSurface: Color(0xFF1F1F1F),
          surfaceContainerHighest: Color(0xFFECECF1),
          onSurfaceVariant: Color(0xFF666870),
          outlineVariant: Color(0xFFD9D9E3),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: chatBg,
          foregroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Apple SD Gothic Neo',
        fontFamilyFallback: const ['Malgun Gothic', 'Dotum', 'sans-serif'],
        scaffoldBackgroundColor: sidebarBg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10A37F),
          onPrimary: Colors.white,
          surface: Color(0xFF202123),
          onSurface: Color(0xFFEDEDED),
          surfaceContainerHighest: Color(0xFF2A2B32),
          onSurfaceVariant: Color(0xFFB4B7C1),
          outlineVariant: Color(0xFF343541),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
