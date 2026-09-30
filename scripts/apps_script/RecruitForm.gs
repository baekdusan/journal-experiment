/**
 * 참가자 모집 폼 — IRB 승인본 기준 문구 + 스크리닝 + 슬롯 선착순(2명) + 배정표 자동 기입.
 *
 * 문구 기준: IRB 변경승인본(2026-09-22, IRB No. 2608/004-010)과 연구참여자 모집 문건.
 * 모집 단계에서는 학습 주제(블록체인)를 노출하지 않는다.
 *
 * ── 설치 (실험운영 시트의 Apps Script 프로젝트, Code.gs와 같은 곳) ──────────────
 *   파일 + → 스크립트 → 이름 "RecruitForm" → 이 내용 붙여 넣기 → 저장.
 *   프로젝트 설정(톱니바퀴) → 시간대 (GMT+09:00) 서울.
 *
 *   A. IRB 문건에 적힌 기존 폼(학교 계정 소유)을 쓰는 경우 — 권장
 *      1) 학교 계정으로 그 폼을 열고 ⋮ → 공동작업자 추가 → dusanisbaek@gmail.com 편집자
 *      2) 그 폼의 편집 주소(docs.google.com/forms/d/…/edit)를 EXISTING_FORM_URL에 넣기
 *      3) 함수 linkExistingForm ▶ 실행 → 권한 승인
 *   B. 새 폼을 만드는 경우: EXISTING_FORM_URL을 비워 두고 createRecruitForm ▶ 실행
 *
 *   어느 쪽이든 실행 로그에 신청 링크가 찍힌다. 두 번 실행해도 문항이 중복되지 않는다.
 *
 * ── 동작 ──────────────────────────────────────────────────────────────
 *   - 응답은 이 시트에 "설문지 응답" 탭으로 쌓인다.
 *   - 스크리닝(기존 폼의 IRB 승인 문항을 읽음): 만 19세 미만, 한국어 불가,
 *     블록체인/암호화폐 전공·실무·자격증, 연구자와 지도·평가 관계면
 *     좌석을 주지 않고 정원에도 세지 않는다. 사유는 참가자에게 알리지 않는다.
 *   - 적격 신청은 **신청 순서대로** 배정표에서 이름이 빈 가장 앞 좌석에 이름을 적고,
 *     비고에 "일시 · 연락처"를 남긴다. 그 행의 참여자 번호를 확정 메일에 넣는다.
 *     (2026-09-28 변경: 슬롯↔세션 고정 매핑을 없앴다. 신청 없는 슬롯이 생겨도 배정표에
 *      구멍이 나지 않고, 배정표의 블록 순서(처치 1·비교 1)를 앞에서부터 그대로 쓴다.)
 *     배정표 좌석이 다 차면 확정하지 않고 대기자로 안내한다 (IRB 최대 모집 인원 보호).
 *   - 슬롯이 CAPACITY명 차거나 **시작 시각이 지나면** 선택지에서 뺀다. 대기자 선택지는 항상 남긴다.
 *     installCleanupTrigger ▶ 1회 실행하면 매시간 지난 슬롯을 자동으로 정리한다.
 *   - 선택지에 남은 자리를 붙여 보여 준다 (예: "10/6(화) 09:00~11:00 (잔여 1자리)").
 *     (2026-09-30 추가.) 응답에도 이 표시가 붙은 채 저장되므로, 응답을 읽는 곳은 모두
 *     slotLabel_로 표시를 떼고 슬롯 문구만 쓴다.
 *   - 일정 변경: 시트에 "일정변경" 탭(1행 헤더: 이름 | 변경 시간)을 두고, 변경 시간은 선택지와
 *     똑같은 문구(예: "10/13(화) 09:00~11:00")로 적는다. 정원 계산이 바뀐 시간 기준이 된다.
 *     참가자 번호·조건은 그대로다. 적은 뒤 resetChoices ▶ 실행.
 *   - 캘린더: "캘린더" 탭에 주별 날짜×시간 표로 신청자·참여 여부를 그린다 (buildCalendar).
 *     폼을 거치지 않고 모신 참가자는 배정표 비고를 슬롯 문구(예: "9/28(월) 09:00~11:00")로
 *     시작하게 적으면 캘린더에 함께 표시된다.
 *     신청이 들어올 때와 매시간(resetChoices) 자동으로 다시 그린다. 손으로 고치지 않는다.
 *   - 슬롯을 바꾸려면 SCHEDULE을 고치고 resetChoices ▶ 실행. 현황은 status ▶ 실행.
 *   - 같은 슬롯에 거의 동시에 제출되면 정원을 넘길 수 있다. 응답 탭에서 보이니 조정한다.
 */

// ── 설정 ─────────────────────────────────────────────────────────────
const EXISTING_FORM_URL = 'https://docs.google.com/forms/d/1ROdwmjejeEYVJrjEL2R5AiZjY9rF6nhlxvMDj8SOZ0E/edit'; // 예: 'https://docs.google.com/forms/d/XXXX/edit'

const SEND_CONFIRMATION_EMAIL = true; // false면 메일 없이 배정표 기입만 (연락은 직접)
const CAPACITY = 2;

// 주마다 월요일과 요일별 시작 시각(0=월 … 6=일). 각 슬롯은 2시간 (19 = 19:00~21:00).
const SCHEDULE = [
  {
    monday: new Date(2026, 8, 28), // 2026-09-28 (월) — 월은 0부터
    hours: {
      0: [9, 11, 13, 15, 17, 19],  // 9/28 월
      1: [9, 11, 13, 15, 17, 19],  // 9/29 화
      2: [9, 11, 18, 20],          // 9/30 수
      3: [18, 20],                 // 10/1 목
      4: [9, 11, 13, 15, 17, 19],  // 10/2 금
      5: [],                       // 10/3 토 (개천절)
      6: [17],                     // 10/4 일 (19시 닫음)
    },
  },
  {
    monday: new Date(2026, 9, 5), // 2026-10-05 (월)
    hours: {
      0: [9, 11, 13, 15, 17, 19],  // 10/5 월
      1: [9, 11, 13, 15, 17, 19],  // 10/6 화
      2: [9, 11, 18, 20],          // 10/7 수
      3: [18, 20],                 // 10/8 목
      4: [17, 19, 21],             // 10/9 금 (한글날) 저녁만 (09시 닫음)
      5: [9, 11, 13, 15, 17, 19],  // 10/10 토
      6: [9, 11, 13, 15, 17, 19],  // 10/11 일
    },
  },
  {
    monday: new Date(2026, 9, 12), // 2026-10-12 (월) — 평일은 1주차와 같게
    hours: {
      0: [9, 11, 13, 15, 17, 19],  // 10/12 월
      1: [9, 11, 13, 15, 17, 19],  // 10/13 화
      2: [9, 11, 18, 20],          // 10/14 수
      3: [18, 20],                 // 10/15 목
      4: [9, 11, 13, 15, 17, 19],  // 10/16 금
      5: [9, 11],                  // 10/17 토 오전만
      6: [9, 11, 13, 15, 17, 19],  // 10/18 일
    },
  },
];

// ── 문구 ─────────────────────────────────────────────────────────────
const FORM_TITLE = 'AI 챗봇 기반 학습 경험 연구 참여 신청';
const CONTACT_LINE = '문의: 백두산 (서울대학교 산업공학과 석사과정) dusanbaek@snu.ac.kr / 010-2248-7291';
const LOCATION_LINE = '장소: 서울대학교 39동 336호 인간공학 실험실';
const FORM_DESCRIPTION = [
  '서울대학교 공과대학 산업공학과에서 진행하는 연구의 참여자를 모집합니다.',
  '',
  '■ 연구 과제명: LLM 챗봇 환경에서 구조화된 학습 설계가 사용성과 학습자 경험에 미치는 영향',
  '■ 연구 목적: AI 챗봇을 활용한 학습 환경에서 학습 진행 방식이 사용성, 학습 경험, 단기 학습성과에 미치는 영향을 인간공학적으로 평가합니다.',
  '■ 참여 내용 (약 1시간 10분): 연구 설명 및 동의(약 5분) → 사전 설문과 사전 지식 확인 문항(약 15분) → AI 챗봇으로 주어진 주제 학습(약 30분, 최대 35분) → 사후 설문(약 5분) → 사후 지식 확인 문항과 주관식 질문(약 15분)',
  '■ ' + LOCATION_LINE,
  '■ 사례: 전 과정 완료 시 15,000원. 참여는 자발적이며 언제든 중단할 수 있고, 중단 시에도 참여 시간에 따라 사례가 지급됩니다.',
  '■ 참여 조건: 만 19세 이상, 한국어 읽기·쓰기 가능, PC로 챗봇 사용에 무리가 없는 분. 일부 전공·경력에 해당하면 참여가 어려울 수 있어 아래에서 간단히 확인합니다.',
  '',
  '신청 내용을 확인한 뒤 참여 확정과 참가자 번호를 안내드립니다.',
  '본 연구는 서울대학교 생명윤리위원회(IRB)의 승인을 받았습니다 (IRB No. 2608/004-010).',
  CONTACT_LINE,
].join('\n');
const CONFIRMATION_MESSAGE = '신청이 접수되었습니다. 참여 조건을 확인한 뒤 확정 안내와 참가자 번호를 보내 드립니다. 메일이 보이지 않으면 스팸함을 확인해 주세요. 실험 전날 입력하신 연락처로 다시 안내드립니다.';

// ── 문항 ─────────────────────────────────────────────────────────────
// 기존 학교 폼(IRB 승인본)의 문항 제목을 그대로 쓴다. 스크립트는 이 문항들을 읽기만 한다.
const Q_NAME = '성명';
const Q_CONTACT = '휴대전화번호';
const Q_AGE = '만 19세 이상입니까?';
const Q_KOREAN = '한국어로 읽기·쓰기 및 의사소통이 가능합니까?';
const Q_BACKGROUND = '다음 분야의 전공·실무 경력·관련 자격증 보유 여부를 표시해 주세요.';
const EXCLUDED_ROW = '블록체인 / 암호화폐';
const Q_RELATION = '현재 연구책임자(백두산)가 직접 지도하거나 성적을 평가하는 수업을 수강 중입니까?';
const SLOT_QUESTION_TITLE = '희망 시간';
const SLOT_HELP = '남아 있는 시간만 표시되며, 괄호 안은 남은 자리 수입니다. 각 슬롯은 2시간이며 실제 소요는 약 1시간 10분입니다. 먼저 신청한 분부터 확정됩니다.';
const WAITLIST = '대기자로 등록 (빈자리가 나면 연락드립니다)';

// 2026-09-28 스크립트 첫 실행 때 중복으로 추가됐던 문항 + 슬롯 예약으로 대체된 옛 문항. 있으면 지운다.
const REMOVE_TITLES = [
  '이름',
  '연락처 (전화번호 또는 카카오톡 아이디)',
  '소속 (학과·학년, 예: 산업공학과 3학년)',
  '만 19세 이상이신가요?',
  '다음 분야의 전공·실무 경력·관련 자격증 보유 여부를 표시해 주세요. (해당 항목 모두)',
  '연구책임자(백두산)에게 직접 지도를 받거나 평가를 받는 관계인가요? (수업 조교·지도 학생 등)',
  '확인',
  '참여 가능한 시간대를 모두 선택해 주세요.',
];

const DAY_NAMES = ['월', '화', '수', '목', '금', '토', '일'];

/** 보이지 않는 문자(소프트 하이픈·제로폭 공백·BOM) 제거 + 앞뒤 공백 정리. */
function clean_(v) {
  return String(v == null ? '' : v).replace(/[\u00AD\u200B-\u200D\u2060\uFEFF]/g, '').trim();
}
/** 이름 비교용 키: clean_ + 공백 제거. */
function nameKey_(v) {
  return clean_(v).replace(/\s+/g, '');
}
/** 선택지·응답값에서 "(잔여 N자리)" 표시를 떼고 슬롯 문구만 남긴다. */
function slotLabel_(v) {
  return clean_(v).replace(/\s*\(잔여 \d+자리\)$/, '');
}
const PROP_FORM_ID = 'RECRUIT_FORM_ID';

// ── 설치 함수 ────────────────────────────────────────────────────────

/** A. 기존 폼(편집 권한 있음)을 연결하고 IRB 기준으로 맞춘다. */
function linkExistingForm() {
  if (!EXISTING_FORM_URL) throw new Error('EXISTING_FORM_URL에 기존 폼의 편집 주소를 넣으세요.');
  const form = FormApp.openByUrl(EXISTING_FORM_URL);
  PropertiesService.getScriptProperties().setProperty(PROP_FORM_ID, form.getId());
  setupForm_(form);
}

/** B. 새 폼을 만들고 IRB 기준으로 맞춘다. */
function createRecruitForm() {
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty(PROP_FORM_ID)) {
    Logger.log('이미 연결된 폼이 있습니다: %s (다시 맞추려면 applyIrbSettings 실행)', form_().getEditUrl());
    return;
  }
  const form = FormApp.create(FORM_TITLE);
  props.setProperty(PROP_FORM_ID, form.getId());
  setupForm_(form);
}

/** 연결된 폼의 문구·문항을 다시 맞춘다 (문구를 고친 뒤 실행). */
function applyIrbSettings() {
  setupForm_(form_());
}

function setupForm_(form) {
  form.setTitle(FORM_TITLE)
    .setDescription(FORM_DESCRIPTION)
    .setConfirmationMessage(CONFIRMATION_MESSAGE);

  // 로그인 없이 응답 가능하게: 이메일은 "응답자 입력"으로 받는다 (인증 방식은 로그인을 강제).
  try { form.setEmailCollectionType(FormApp.EmailCollectionType.RESPONDER_INPUT); }
  catch (err) { form.setCollectEmail(true); Logger.log('이메일 수집 방식 변경 불가: %s', err); }
  try { form.setRequireLogin(false); }
  catch (err) { Logger.log('로그인 제한 해제 불가(학교 계정에서 직접 해제 필요): %s', err); }

  // 중복·대체 문항 삭제
  const removed = [];
  form.getItems().forEach(it => {
    if (REMOVE_TITLES.includes(it.getTitle())) { removed.push(it.getTitle()); form.deleteItem(it); }
  });

  // 희망 시간(슬롯) 문항: 없으면 만들고, "희망 날짜나 참고 사항" 바로 앞에 둔다.
  let slot = findItem_(form, SLOT_QUESTION_TITLE, FormApp.ItemType.MULTIPLE_CHOICE);
  if (!slot) slot = form.addMultipleChoiceItem().setTitle(SLOT_QUESTION_TITLE).setChoiceValues([WAITLIST]);
  slot.asMultipleChoiceItem().setHelpText(SLOT_HELP).setRequired(true);
  const note = form.getItems().filter(i => i.getTitle().indexOf('희망 날짜나 참고 사항') === 0)[0];
  if (note && slot.getIndex() > note.getIndex()) form.moveItem(slot.getIndex(), note.getIndex());

  // 스크리닝 문항이 제대로 있는지 확인 (없으면 판정이 통과로 처리되므로 경고)
  [Q_NAME, Q_CONTACT, Q_AGE, Q_KOREAN, Q_BACKGROUND, Q_RELATION].forEach(t => {
    if (!form.getItems().some(i => i.getTitle() === t)) Logger.log('경고: 문항 "%s"이 폼에 없습니다.', t);
  });

  resetChoices();
  form.setDestination(FormApp.DestinationType.SPREADSHEET, SpreadsheetApp.getActive().getId());
  installTrigger_(form);

  Logger.log('삭제한 문항: %s', removed.length ? removed.join(' / ') : '없음');
  Logger.log('최종 문항: %s', form.getItems().map(i => i.getTitle()).join(' / '));
  Logger.log('완료. 슬롯 %s개, 정원 %s명/슬롯', buildSlots_().length, CAPACITY);
  Logger.log('신청 링크: %s', form.getPublishedUrl());
}

function findItem_(form, title, type) {
  return form.getItems(type).filter(i => i.getTitle() === title)[0] || null;
}

function installTrigger_(form) {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'onSubmit')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('onSubmit').forForm(form).onFormSubmit().create();
}

function form_() {
  const id = PropertiesService.getScriptProperties().getProperty(PROP_FORM_ID);
  if (!id) throw new Error('연결된 폼이 없습니다. linkExistingForm 또는 createRecruitForm을 먼저 실행하세요.');
  return FormApp.openById(id);
}

// ── 슬롯 ─────────────────────────────────────────────────────────────

/** 슬롯 목록: { label: "9/28(월) 09:00~11:00", start: 시작 시각(한국 시간 기준) }. 시간순. */
function slotObjects_() {
  const out = [];
  SCHEDULE.forEach(week => {
    const y = week.monday.getFullYear(), m = week.monday.getMonth(), d0 = week.monday.getDate();
    for (let d = 0; d < 7; d++) {
      (week.hours[d] || []).forEach(h => {
        // 스크립트 시간대 설정과 무관하게 한국 시간(UTC+9)으로 계산한다.
        const start = new Date(Date.UTC(y, m, d0 + d, h - 9));
        const kst = new Date(Date.UTC(y, m, d0 + d));
        const hh = String(h).padStart(2, '0');
        const end = String(h + 2).padStart(2, '0');
        out.push({
          label: `${kst.getUTCMonth() + 1}/${kst.getUTCDate()}(${DAY_NAMES[d]}) ${hh}:00~${end}:00`,
          start: start,
        });
      });
    }
  });
  return out;
}

function buildSlots_() {
  return slotObjects_().map(o => o.label);
}

/** 아직 시작 전이고 정원이 남은 슬롯. */
function openSlots_(counts) {
  const now = new Date();
  return slotObjects_()
    .filter(o => o.start > now && (counts[o.label] || 0) < CAPACITY)
    .map(o => o.label);
}

function slotItem_() {
  const it = findItem_(form_(), SLOT_QUESTION_TITLE, FormApp.ItemType.MULTIPLE_CHOICE);
  if (!it) throw new Error(`객관식 문항 "${SLOT_QUESTION_TITLE}"이 폼에 없습니다. applyIrbSettings를 실행하세요.`);
  return it.asMultipleChoiceItem();
}

/** 선택지를 SCHEDULE 기준으로 다시 채운다 (찬 슬롯·지난 슬롯은 제외, 남은 자리 표시). */
function resetChoices() {
  const counts = countBySlot_();
  const next = [
    ...openSlots_(counts).map(l => `${l} (잔여 ${CAPACITY - (counts[l] || 0)}자리)`),
    WAITLIST,
  ];
  const item = slotItem_();
  const cur = item.getChoices().map(c => c.getValue());
  if (cur.join('|') !== next.join('|')) item.setChoiceValues(next);
  if (item.getHelpText() !== SLOT_HELP) item.setHelpText(SLOT_HELP);
  try { buildCalendar(); } catch (err) { Logger.log('캘린더 갱신 실패: %s', err); }
}

/** 1회 실행: 매시간 resetChoices를 돌려 지난 슬롯을 자동으로 뺀다. */
function installCleanupTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'resetChoices')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('resetChoices').timeBased().everyHours(1).create();
  resetChoices();
  Logger.log('매시간 정리 트리거 설치 완료. 지금 열린 슬롯: %s개', openSlots_(countBySlot_()).length);
}

/** "일정변경" 탭: 이름 → 변경 시간. 탭이 없으면 빈 맵. */
function reschedules_() {
  const sh = SpreadsheetApp.getActive().getSheetByName('일정변경');
  if (!sh) return {};
  const out = {};
  sh.getDataRange().getDisplayValues().slice(1).forEach(r => {
    const name = nameKey_(r[0]);
    const slot = slotLabel_(r[1]);
    if (name && slot) out[name] = slot;
  });
  return out;
}

/** 적격 신청만 슬롯별로 센다 (일정변경 반영). 대기자는 세지 않는다. */
function countBySlot_() {
  const counts = {};
  const moved = reschedules_();
  form_().getResponses().forEach(r => {
    if (!eligibility_(r).ok) return;
    let slot = null, name = '';
    r.getItemResponses().forEach(ir => {
      const t = ir.getItem().getTitle();
      if (t === SLOT_QUESTION_TITLE) slot = slotLabel_(ir.getResponse());
      if (t === Q_NAME) name = nameKey_(ir.getResponse());
    });
    if (!slot || slot === WAITLIST) return;
    const v = moved[name] || slot;
    counts[v] = (counts[v] || 0) + 1;
  });
  return counts;
}

/** 현황 (실행 로그). */
function status() {
  const counts = countBySlot_();
  const now = new Date();
  slotObjects_().forEach(o =>
    Logger.log('%s  %s/%s%s', o.label, counts[o.label] || 0, CAPACITY, o.start <= now ? '  (지남)' : ''));
}

// ── 스크리닝 ─────────────────────────────────────────────────────────

/** IRB 선정·제외 기준 충족 여부. 사유는 내부 기록용(참가자에게 보내지 않음). */
function eligibility_(response) {
  let age = null, korean = null, relation = null, bg = null, rows = null;
  response.getItemResponses().forEach(ir => {
    const it = ir.getItem();
    const t = it.getTitle();
    if (t === Q_AGE) age = String(ir.getResponse());
    if (t === Q_KOREAN) korean = String(ir.getResponse());
    if (t === Q_RELATION) relation = String(ir.getResponse());
    if (t === Q_BACKGROUND) {
      bg = ir.getResponse(); // 행별 배열
      rows = it.getType() === FormApp.ItemType.CHECKBOX_GRID ? it.asCheckboxGridItem().getRows()
           : it.getType() === FormApp.ItemType.GRID ? it.asGridItem().getRows() : null;
    }
  });
  const no = v => v != null && /^아니/.test(v.trim());
  const yes = v => v != null && /^예/.test(v.trim());
  if (no(age)) return { ok: false, reason: '만 19세 미만' };
  if (no(korean)) return { ok: false, reason: '한국어 의사소통 불가' };
  if (yes(relation)) return { ok: false, reason: '연구자와 지도·평가 관계' };
  if (bg && rows) {
    const idx = rows.indexOf(EXCLUDED_ROW);
    const cells = idx < 0 ? [] : [].concat(bg[idx] || []).filter(v => v && !/해당\s*없음/.test(v));
    if (cells.length) return { ok: false, reason: '제외 분야 경력: ' + cells.join(', ') };
  }
  return { ok: true };
}

// ── 제출 처리 ────────────────────────────────────────────────────────

function onSubmit(e) {
  const response = e && e.response;
  if (!response) return;
  const answers = {};
  response.getItemResponses().forEach(ir => { answers[ir.getItem().getTitle()] = ir.getResponse(); });
  const chosen = answers[SLOT_QUESTION_TITLE] ? slotLabel_(answers[SLOT_QUESTION_TITLE]) : null;
  const email = response.getRespondentEmail();

  // 1. 찬 슬롯·지난 슬롯을 선택지에서 빼고 남은 자리 표시를 갱신한다.
  resetChoices();

  // 2. 스크리닝. 부적격이면 좌석을 주지 않고 중립 안내만 한다.
  const elig = eligibility_(response);
  if (!elig.ok) {
    Logger.log('스크리닝 제외: %s', elig.reason);
    if (SEND_CONFIRMATION_EMAIL && email) {
      MailApp.sendEmail(email, '[AI 챗봇 학습 경험 연구] 신청 결과 안내', [
        '관심을 가지고 신청해 주셔서 감사합니다.',
        '아쉽지만 이번 연구의 참여 조건에 해당하지 않아 참여가 어렵습니다.',
        '', CONTACT_LINE,
      ].join('\n'));
    }
    return;
  }

  // 3. 배정표에 이름 기입 → 참가자 번호.
  const isWaitlist = chosen === WAITLIST;
  let pid = null;
  if (chosen && !isWaitlist) {
    pid = assignSeat_(chosen, clean_(answers[Q_NAME]), clean_(answers[Q_CONTACT]));
  }

  try { buildCalendar(); } catch (err) { Logger.log('캘린더 갱신 실패: %s', err); }

  // 배정표 좌석이 다 찼으면 확정하지 않는다 (IRB 최대 모집 인원 보호).
  const full = chosen && !isWaitlist && !pid;
  if (full) Logger.log('배정표 좌석 없음: %s 신청을 대기로 처리', chosen);

  // 4. 확정 메일.
  if (!SEND_CONFIRMATION_EMAIL || !email || !chosen) return;
  if (full) {
    MailApp.sendEmail(email, '[AI 챗봇 학습 경험 연구] 신청 결과 안내', [
      '신청해 주셔서 감사합니다. 현재 모집 인원이 모두 찼습니다.',
      '대기자로 기록해 두었다가 빈자리가 생기면 연락드리겠습니다.',
      '', CONTACT_LINE,
    ].join('\n'));
    return;
  }
  const subject = isWaitlist
    ? '[AI 챗봇 학습 경험 연구] 대기자 등록 안내'
    : `[AI 챗봇 학습 경험 연구] 참여 확정: ${chosen}`;
  const body = isWaitlist
    ? ['대기자로 등록되었습니다. 빈자리가 나면 순서대로 연락드리겠습니다.', '', CONTACT_LINE]
    : [
        '참여가 확정되었습니다.',
        '',
        pid ? `참가자 번호: ${pid}  (실험 당일 이 번호와 이름을 입력합니다)` : null,
        `일시: ${chosen}`,
        LOCATION_LINE,
        '소요 시간: 약 1시간 10분 (컴퓨터 준비되어 있음, 준비물 없음)',
        '사례: 전 과정 완료 시 15,000원 (중단 시에도 참여 시간에 따라 지급)',
        '',
        '시작 시각에 맞춰 도착해 주세요. 참여가 어려워지면 미리 알려 주시면 다른 분께 기회가 갑니다.',
        '', CONTACT_LINE,
      ];
  MailApp.sendEmail(email, subject, body.filter(l => l !== null).join('\n'));
}

/**
 * 신청 순서대로 배정표에서 이름이 빈 가장 앞 좌석에 이름을 적고 참여자 번호를 돌려준다.
 * 사용 여부가 '불참'인 행은 건너뛴다. 빈 좌석이 없으면 null.
 * 동시 제출로 같은 좌석을 두 번 쓰지 않도록 잠금을 건다.
 */
function assignSeat_(slotLabel, name, contact) {
  if (!name) return null;
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    return assignSeatLocked_(slotLabel, name, contact);
  } finally {
    lock.releaseLock();
  }
}

function assignSeatLocked_(slotLabel, name, contact) {
  const sheet = SpreadsheetApp.getActive().getSheetByName('배정표');
  if (!sheet) return null;
  const rows = sheet.getDataRange().getValues();
  let h = -1;
  const col = {};
  for (let r = 0; r < Math.min(rows.length, 20) && h < 0; r++) {
    rows[r].forEach((cell, c) => {
      const t = String(cell || '').replace(/\s+/g, '');
      if (t === '세션') col.session = c;
      if (t === '참여자번호' || t === '참가자번호') col.pid = c;
      if (t === '이름') col.name = c;
      if (t === '비고') col.note = c;
      if (t === '사용여부') col.used = c;
    });
    if (col.pid != null && col.name != null) h = r;
  }
  if (h < 0) return null;
  for (let i = h + 1; i < rows.length; i++) {
    if (!String(rows[i][col.pid] || '').trim()) continue;
    if (String(rows[i][col.name] || '').trim()) continue;
    if (col.used != null && /불참/.test(String(rows[i][col.used] || ''))) continue;
    sheet.getRange(i + 1, col.name + 1).setValue(name);
    if (col.note != null && !rows[i][col.note]) {
      sheet.getRange(i + 1, col.note + 1).setValue(contact ? `${slotLabel} · ${contact}` : slotLabel);
    }
    return String(rows[i][col.pid]);
  }
  return null;
}

// ── 캘린더 ───────────────────────────────────────────────────────────

const CALENDAR_SHEET = '캘린더';
const CAL_COLORS = {
  none: '#eeeeee',     // 슬롯 없음
  empty: '#ffffff',    // 빈자리
  half: '#fff2cc',     // 1/2
  full: '#d9ead3',     // 2/2
  pastEmpty: '#f8f8f8' // 지났는데 비어 있음
};

/** 적격 신청 목록: [{ name, slot }] (일정변경 반영, 대기자 제외). */
function bookings_() {
  const moved = reschedules_();
  const out = [];
  form_().getResponses().forEach(r => {
    if (!eligibility_(r).ok) return;
    let slot = null, name = '';
    r.getItemResponses().forEach(ir => {
      const t = ir.getItem().getTitle();
      if (t === SLOT_QUESTION_TITLE) slot = slotLabel_(ir.getResponse());
      if (t === Q_NAME) name = clean_(ir.getResponse());
    });
    if (!slot || slot === WAITLIST) return;
    out.push({ name: name, slot: moved[nameKey_(name)] || slot });
  });
  return out;
}

/** 배정표: 이름(공백 제거) → { pid, used } */
function roster_() {
  const sheet = SpreadsheetApp.getActive().getSheetByName('배정표');
  if (!sheet) return {};
  const rows = sheet.getDataRange().getDisplayValues();
  let h = -1;
  const col = {};
  for (let r = 0; r < Math.min(rows.length, 20) && h < 0; r++) {
    rows[r].forEach((cell, c) => {
      const t = String(cell || '').replace(/\s+/g, '');
      if (t === '참여자번호' || t === '참가자번호') col.pid = c;
      if (t === '이름') col.name = c;
      if (t === '사용여부') col.used = c;
      if (t === '비고') col.note = c;
    });
    if (col.pid != null && col.name != null) h = r;
  }
  const out = {};
  if (h < 0) return out;
  for (let i = h + 1; i < rows.length; i++) {
    const raw = clean_(rows[i][col.name]);
    const n = nameKey_(raw);
    if (n) out[n] = {
      pid: rows[i][col.pid],
      name: raw,
      used: col.used != null ? rows[i][col.used] : '',
      note: col.note != null ? clean_(rows[i][col.note]) : '',
    };
  }
  return out;
}

/** "캘린더" 탭을 다시 그린다. 주별로 가로=날짜, 세로=시간. */
function buildCalendar() {
  const ss = SpreadsheetApp.getActive();
  const sh = ss.getSheetByName(CALENDAR_SHEET) || ss.insertSheet(CALENDAR_SHEET);
  const slots = slotObjects_();
  const byLabel = {};
  slots.forEach(o => { byLabel[o.label] = o; });
  const people = {};
  const roster = roster_();
  const seen = {};
  bookings_().forEach(b => {
    (people[b.slot] = people[b.slot] || []).push(b.name);
    seen[nameKey_(b.name)] = true;
  });
  // 폼을 거치지 않고 모신 참가자: 배정표 비고가 슬롯 문구로 시작하면 그 칸에 표시한다.
  Object.keys(roster).forEach(k => {
    if (seen[k]) return;
    const note = roster[k].note || '';
    const label = Object.keys(byLabel).find(l => note.indexOf(l) === 0);
    if (label) (people[label] = people[label] || []).push(roster[k].name);
  });
  const hours = [...new Set(slots.map(o => Number(o.label.slice(-11, -9))))].sort((a, b) => a - b);
  const now = new Date();

  const values = [];
  const colors = [];
  const weights = [];
  const width = 8;
  const pushRow = (v, c, w) => {
    while (v.length < width) v.push('');
    while (c.length < width) c.push(null);
    values.push(v); colors.push(c); weights.push(w || Array(width).fill('normal'));
  };

  let total = 0, filled = 0, done = 0;
  SCHEDULE.forEach((week, wi) => {
    const y = week.monday.getFullYear(), m = week.monday.getMonth(), d0 = week.monday.getDate();
    const days = [];
    for (let d = 0; d < 7; d++) {
      const k = new Date(Date.UTC(y, m, d0 + d));
      days.push(`${k.getUTCMonth() + 1}/${k.getUTCDate()}(${DAY_NAMES[d]})`);
    }
    pushRow([`${wi + 1}주차  ${days[0]} ~ ${days[6]}`], [], Array(width).fill('bold'));
    pushRow(['시간', ...days], Array(width).fill('#d0e0e3'), Array(width).fill('bold'));
    hours.forEach(h => {
      const hh = String(h).padStart(2, '0');
      const label = `${hh}:00~${String(h + 2).padStart(2, '0')}:00`;
      const row = [label];
      const rowColors = ['#f3f3f3'];
      days.forEach(day => {
        const key = `${day} ${label}`;
        const slot = byLabel[key];
        if (!slot) { row.push(''); rowColors.push(CAL_COLORS.none); return; }
        total++;
        const names = people[key] || [];
        filled += names.length;
        const past = slot.start <= now;
        const lines = names.map(n => {
          const r = roster[nameKey_(n)] || {};
          const mark = /사용/.test(r.used) ? ' ✓' : /불참/.test(r.used) ? ' ✗' : '';
          if (mark === ' ✓') done++;
          return `${r.pid || '?'} ${n}${mark}`;
        });
        if (names.length === 0) {
          row.push(past ? '(지남)' : '빈자리 2');
          rowColors.push(past ? CAL_COLORS.pastEmpty : CAL_COLORS.empty);
        } else {
          if (names.length < CAPACITY && !past) lines.push(`빈자리 ${CAPACITY - names.length}`);
          row.push(lines.join('\n'));
          rowColors.push(names.length >= CAPACITY ? CAL_COLORS.full : CAL_COLORS.half);
        }
      });
      pushRow(row, rowColors);
    });
    pushRow([], []);
  });

  const stamp = Utilities.formatDate(now, 'Asia/Seoul', 'M/d HH:mm');
  pushRow([`갱신 ${stamp}  ·  슬롯 ${total}개, 신청 ${filled}명, 참여 완료 ${done}명  ·  ✓ 참여 완료  ✗ 불참  ·  노랑 1/2, 초록 2/2, 회색 슬롯 없음  ·  자동 생성 탭이니 직접 고치지 마세요`], []);

  sh.clear();
  const range = sh.getRange(1, 1, values.length, width);
  range.setValues(values).setBackgrounds(colors).setFontWeights(weights)
    .setWrap(true).setVerticalAlignment('top').setFontSize(10);
  sh.setColumnWidth(1, 90);
  sh.setColumnWidths(2, 7, 150);
  sh.setFrozenRows(0);
}
