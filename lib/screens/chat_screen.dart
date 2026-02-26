import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/sidebar.dart';
import '../widgets/chat_view.dart';

/// 채팅 앱의 메인 화면으로, 반응형 레이아웃을 구현한다.
///
/// 화면 너비 900px을 기준으로 레이아웃이 변경된다:
/// - **데스크탑 (900px 초과)**: [Sidebar]를 왼쪽에 고정 표시하고 AppBar를 숨김
/// - **모바일 (900px 이하)**: [Sidebar]를 [Drawer]로 숨기고 AppBar를 표시
///
/// [ChatView]는 항상 메인 콘텐츠 영역에 표시된다.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 900;

        return Scaffold(
          appBar: isLargeScreen
              ? null
              : AppBar(
                  title: const Text(
                    'Instructional Tutoring System',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
          drawer: isLargeScreen
              ? null
              : const Drawer(
                  width: 280,
                  child: Sidebar(),
                ),
          body: Row(
            children: [
              if (isLargeScreen) const Sidebar(),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const ChatView(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
