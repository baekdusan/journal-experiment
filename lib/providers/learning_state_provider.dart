import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learning_state.dart';
import '../models/learner_profile.dart';
import '../models/instructional_design.dart';

part 'learning_state_provider.g.dart';

const _learningStateStorageKey = 'learning_state_v1';

@riverpod
class LearningStateNotifier extends _$LearningStateNotifier {
  @override
  LearningState build() {
    final initial = LearningState.initial();
    unawaited(_loadFromPrefs());
    return initial;
  }

  Future<void> updateFromExtractedInfo({
    String? subject,
    String? goal,
    LearnerLevel? level,
    TonePreference? tonePreference,
  }) async {
    final current = state;
    final normalizedSubject = _normalizeText(subject);
    final normalizedGoal = _normalizeText(goal);
    debugPrint(
      '[State] update\nsubject=$normalizedSubject\ngoal=$normalizedGoal\nlevel=${level?.name}\ntone=${tonePreference?.name}\n',
    );
    final subjectChanged =
        normalizedSubject != null && normalizedSubject != current.learnerProfile.subject;
    final goalChanged =
        normalizedGoal != null && normalizedGoal != current.learnerProfile.goal;

    // 주제가 바뀌었는데 같은 발화에 새 목표가 없으면 이전 목표를 비운다.
    // 비우지 않으면 옛 주제의 목표로 새 주제의 설계가 곧바로 시작된다
    // (2026-09-28 P003: "블록체인"·"스마트 컨트랙트"로 바꿨는데 "해시 함수" 목표가 남아
    //  해시 함수 과정이 다시 짜임). 비우면 Analyst가 다음 턴에 목표를 받아 설계를 시작한다.
    // copyWith는 null을 "유지"로 처리하므로 생성자로 직접 만든다.
    // 수준·말투는 학습자에 대한 정보라 주제가 바뀌어도 유지한다.
    final keepGoal = !subjectChanged || normalizedGoal != null;
    final updatedProfile = LearnerProfile(
      subject: normalizedSubject ?? current.learnerProfile.subject,
      goal: normalizedGoal ?? (keepGoal ? current.learnerProfile.goal : null),
      level: level ?? current.learnerProfile.level,
      tonePreference: tonePreference ?? current.learnerProfile.tonePreference,
    );

    final resetDesign =
        (subjectChanged || goalChanged) && current.instructionalDesign.isDesignFilled;
    final updatedDesign = resetDesign
        ? InstructionalDesign.empty()
        : current.instructionalDesign;

    state = current.copyWith(
      learnerProfile: updatedProfile,
      instructionalDesign: updatedDesign,
      isDesigning: resetDesign ? false : current.isDesigning,
      showDesignReady: resetDesign ? false : current.showDesignReady,
      isCourseCompleted: resetDesign ? false : current.isCourseCompleted,
      currentStepIndex: resetDesign ? 0 : current.currentStepIndex,
      updatedAt: DateTime.now(),
    );

    debugPrint(
      '[State] flags\nmandatory=${state.learnerProfile.isLearnerProfileFilled}\nisDesignFilled=${state.instructionalDesign.isDesignFilled}\ndesigning=${state.isDesigning}\ncompleted=${state.isCourseCompleted}',
    );

    await _saveToPrefs();
  }

  Future<void> setDesigning(bool value) async {
    state = state.copyWith(
      isDesigning: value,
      showDesignReady: value ? false : state.showDesignReady,
      updatedAt: DateTime.now(),
    );
    await _saveToPrefs();
  }

  Future<void> setSyllabus(List<Step> syllabus) async {
    state = state.copyWith(
      instructionalDesign: state.instructionalDesign.copyWith(
        syllabus: syllabus,
      ),
      isDesigning: false,
      showDesignReady: true,
      isCourseCompleted: false,
      // 신규 생성·재설계 모두 이 경로를 거치므로 현재 단계를 0으로 초기화한다.
      currentStepIndex: 0,
      updatedAt: DateTime.now(),
    );
    await _saveToPrefs();
  }

  /// 현재 학습 단계를 설정한다(syllabus 범위로 클램프).
  /// 단조 전진(증가)은 호출부([ChatController])가 완료 신호로 보장한다.
  Future<void> setCurrentStep(int index) async {
    final lastIndex = state.instructionalDesign.syllabus.length - 1;
    final clamped = index.clamp(0, lastIndex < 0 ? 0 : lastIndex);
    if (clamped == state.currentStepIndex) return;
    state = state.copyWith(
      currentStepIndex: clamped,
      updatedAt: DateTime.now(),
    );
    await _saveToPrefs();
  }

  Future<void> setDesignReady(bool value) async {
    state = state.copyWith(showDesignReady: value, updatedAt: DateTime.now());
    await _saveToPrefs();
  }

  Future<void> markCourseCompleted() async {
    state = state.copyWith(isCourseCompleted: true, updatedAt: DateTime.now());
    await _saveToPrefs();
  }

  Future<void> resetCourseCompleted() async {
    state = state.copyWith(isCourseCompleted: false, updatedAt: DateTime.now());
    await _saveToPrefs();
  }

  Future<void> reset() async {
    state = LearningState.initial();
    await _saveToPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learningStateStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      state = LearningState.fromJson(data);
    } catch (_) {
      // Ignore invalid persisted data
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.toJson());
    await prefs.setString(_learningStateStorageKey, encoded);
  }

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }
}
