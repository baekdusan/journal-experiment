import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/experiment_config.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

/// 실험 시작 화면.
///
/// 배포 빌드(REGISTRY_URL 있음): **참가자 번호 + 이름** → 실험운영 시트의 배정표에서
/// 조회해 일치할 때만 시작한다. 조건은 시트에서 오고 화면에는 나오지 않는다.
///
/// 로컬 빌드(REGISTRY_URL 없음): 참가자 번호 + 그룹 A/B 직접 선택.
/// 매핑은 [ExperimentConfig.blindLabels]에만 있다.
///
/// 시작 버튼이 실험의 t=0이다. 누르는 순간 대화·학습 상태·텔레메트리를 초기화하고
/// 참가자·조건·시작 시각을 기록한 뒤 채팅 화면으로 넘어간다.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  late final TextEditingController _pid;
  late final TextEditingController _name;
  String? _group;
  bool _checking = false;
  String? _error;

  bool get _useRegistry =>
      ref.read(participantRegistryServiceProvider).isEnabled;

  @override
  void initState() {
    super.initState();
    _pid = TextEditingController(
      text: ExperimentConfig.participantIdFromUrl ?? '',
    );
    _name = TextEditingController();
    _pid.addListener(_onChanged);
    _name.addListener(_onChanged);
    final fromUrl = ExperimentConfig.conditionFromUrl;
    if (fromUrl != null) _group = ExperimentConfig.blindLabelFor(fromUrl);
  }

  void _onChanged() => setState(() => _error = null);

  @override
  void dispose() {
    _pid.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _pidText => _pid.text.trim();
  String get _nameText => _name.text.trim();

  bool get _canStart {
    if (_checking || _pidText.isEmpty) return false;
    return _useRegistry ? _nameText.isNotEmpty : _group != null;
  }

  Future<void> _start() async {
    if (!_canStart) return;
    final controller = ref.read(chatControllerProvider.notifier);

    if (_useRegistry) {
      setState(() {
        _checking = true;
        _error = null;
      });
      final result = await ref
          .read(participantRegistryServiceProvider)
          .lookup(pid: _pidText, name: _nameText);
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _checking = false;
          _error = result.message;
        });
        return;
      }
      ExperimentConfig.setCondition(result.condition!);
      controller.startExperiment(result.pid ?? _pidText, displayName: _nameText);
    } else {
      final condition = ExperimentConfig.conditionForBlindLabel(_group);
      if (condition == null) return;
      ExperimentConfig.setCondition(condition);
      controller.startExperiment(_pidText);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glowColor = isDark
        ? const Color(0xFF0842A0).withValues(alpha: 0.25)
        : const Color(0xFFD3E3FD).withValues(alpha: 0.9);
    final useRegistry = _useRegistry;

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? cs.surfaceContainer : cs.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.05),
            radius: 0.85,
            colors: [glowColor, glowColor.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 28, color: Color(0xFF4E86FF)),
                      const SizedBox(width: 10),
                      Text(
                        'AI Tutor',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    useRegistry
                        ? '참가자 번호와 이름을 입력한 뒤 시작해 주세요.'
                        : '참가자 번호와 안내받은 그룹을 선택한 뒤 시작해 주세요.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    key: const ValueKey('participant-name'),
                    controller: _pid,
                    autofocus: true,
                    enabled: !_checking,
                    textInputAction: TextInputAction.next,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                    decoration: deco('참가자 번호'),
                  ),
                  const SizedBox(height: 16),
                  if (useRegistry)
                    TextField(
                      key: const ValueKey('participant-display-name'),
                      controller: _name,
                      enabled: !_checking,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _start(),
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                      decoration: deco('이름'),
                    )
                  else
                    SegmentedButton<String>(
                      key: const ValueKey('group-selector'),
                      segments: [
                        for (final label in ExperimentConfig.blindLabels.keys)
                          ButtonSegment(value: label, label: Text('그룹 $label')),
                      ],
                      selected: _group == null ? const {} : {_group!},
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _group = s.isEmpty ? null : s.first),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('start-error'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('start-button'),
                    onPressed: _canStart ? _start : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '시작하기',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
