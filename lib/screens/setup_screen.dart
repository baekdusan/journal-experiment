import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/experiment_config.dart';
import 'start_screen.dart';

/// 진행자용 설정 화면. 참가자에게 넘기기 전에 조건과 PC 라벨을 고른다.
///
/// URL 쿼리로 조건을 넣다가 실수하는 것을 막기 위해 **명시적 선택을 강제**한다.
/// 조건을 고르지 않으면 다음으로 갈 수 없다. URL이나 직전 선택이 있으면
/// 미리 선택해 두지만, 확인 버튼은 진행자가 눌러야 한다.
/// 이 화면 이후(시작 화면·채팅 화면)에는 조건이 어디에도 표시되지 않는다.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _prefCondition = 'setup_condition';
  static const _prefStation = 'setup_station';

  ExperimentCondition? _condition;
  late final TextEditingController _station;

  @override
  void initState() {
    super.initState();
    _condition = ExperimentConfig.conditionFromUrl;
    _station = TextEditingController(text: ExperimentConfig.stationFromUrl ?? '');
    _loadPrevious();
  }

  Future<void> _loadPrevious() async {
    if (_condition != null && _station.text.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final c = prefs.getString(_prefCondition);
      final s = prefs.getString(_prefStation);
      if (!mounted) return;
      setState(() {
        _condition ??= c == null
            ? null
            : ExperimentCondition.values.cast<ExperimentCondition?>().firstWhere(
                  (e) => e!.name == c,
                  orElse: () => null,
                );
        if (_station.text.isEmpty && s != null) _station.text = s;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _station.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final c = _condition;
    if (c == null) return;
    ExperimentConfig.setCondition(c);
    ExperimentConfig.setStation(_station.text);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCondition, c.name);
      await prefs.setString(_prefStation, _station.text.trim());
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined,
                        size: 22, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      '실험 설정 (진행자용)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '참가자에게 넘기기 전에 설정합니다. 다음 화면부터는 조건이 표시되지 않습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text('조건', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<ExperimentCondition>(
                  key: const ValueKey('condition-selector'),
                  segments: const [
                    ButtonSegment(
                      value: ExperimentCondition.treatment,
                      label: Text('처치군 (구조화)'),
                      icon: Icon(Icons.account_tree_outlined),
                    ),
                    ButtonSegment(
                      value: ExperimentCondition.control,
                      label: Text('대조군 (순수 모델)'),
                      icon: Icon(Icons.chat_bubble_outline),
                    ),
                  ],
                  selected: _condition == null ? const {} : {_condition!},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _condition = s.isEmpty ? null : s.first),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('station-field'),
                  controller: _station,
                  decoration: const InputDecoration(
                    labelText: 'PC 라벨 (선택, 예: A / B)',
                    helperText: '파일명과 JSON에 기록되어 어느 컴퓨터에서 나온 데이터인지 구분합니다.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('setup-confirm'),
                  onPressed: _condition == null ? null : _confirm,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('참가자 화면으로', style: TextStyle(fontSize: 16)),
                  ),
                ),
                if (_condition == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '조건을 골라야 넘어갈 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
