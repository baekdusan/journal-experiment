import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';

/// 채팅 세션 목록과 새 채팅 버튼을 제공하는 사이드바 위젯.
///
/// [chatSessionsProvider]를 구독하여 세션 목록을 표시하고,
/// [activeSessionIdProvider]로 현재 선택된 세션을 하이라이트한다.
/// "New Chat" 버튼 클릭 시 [ChatController.createNewSession]을 호출하고,
/// 세션 항목 클릭 시 해당 세션을 활성화한다.
/// 각 세션 옆에는 다운로드 버튼이 표시되어 세션을 JSON 파일로 내보낼 수 있다.
///
/// 데스크탑에서는 화면 왼쪽에 고정 표시되고, 모바일에서는 [Drawer] 내부에 표시된다.
class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  // 다운로드 중인 세션 ID를 추적
  final Set<String> _downloadingSessionIds = {};

  /// 세션 다운로드를 처리하는 핸들러
  Future<void> _handleDownload(String sessionId) async {
    if (_downloadingSessionIds.contains(sessionId)) {
      return; // 이미 다운로드 중
    }

    setState(() {
      _downloadingSessionIds.add(sessionId);
    });

    try {
      await ref.read(chatControllerProvider.notifier).downloadSession(sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('세션이 다운로드되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 실패: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingSessionIds.remove(sessionId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(chatSessionsProvider);
    final activeId = ref.watch(activeSessionIdProvider);
    const sidebarColor = Color(0xFF171717);
    const activeItemColor = Color(0xFF2A2B32);
    const textColor = Color(0xFFEDEDED);
    const mutedColor = Color(0xFFA6A7B0);

    return Container(
      width: 280,
      color: sidebarColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(chatControllerProvider.notifier).createNewSession();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: textColor,
                side: const BorderSide(color: Color(0xFF3B3D47)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = session.id == activeId;

                final isDownloading = _downloadingSessionIds.contains(session.id);

                return ListTile(
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                  selected: isActive,
                  selectedTileColor: activeItemColor,
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  onTap: () {
                    ref.read(activeSessionIdProvider.notifier).set(session.id);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 다운로드 버튼 (로딩 중이면 스피너 표시)
                      if (isDownloading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: mutedColor,
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.download,
                            size: 16,
                            color: mutedColor,
                          ),
                          onPressed: () => _handleDownload(session.id),
                          tooltip: '세션 다운로드',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      // 활성 세션 표시
                      if (isActive)
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: mutedColor,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
