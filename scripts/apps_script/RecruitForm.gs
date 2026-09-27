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
 *   - 스크리닝: 만 19세 미만, 블록체인/암호화폐 전공·실무·자격증, 연구자와 지도·평가 관계면
 *     좌석을 주지 않고 정원에도 세지 않는다. 사유는 참가자에게 알리지 않는다.
 *   - 적격 신청은 배정표에서 "세션 = 슬롯 순번 + SESSION_OFFSET"인 행 중 이름이 빈 첫 좌석에
 *     이름을 적고, 비고에 "일시 · 연락처"를 남긴다. 그 행의 참여자 번호를 확정 메일에 넣는다.
 *   - 슬롯이 CAPACITY명 차면 선택지에서 뺀다. 대기자 선택지는 항상 남긴다.
 *   - 슬롯을 바꾸려면 SCHEDULE을 고치고 resetChoices ▶ 실행. 현황은 status ▶ 실행.
 *   - 같은 슬롯에 거의 동시에 제출되면 정원을 넘길 수 있다. 응답 탭에서 보이니 조정한다.
 */

// ── 설정 ─────────────────────────────────────────────────────────────
const EXISTING_FORM_URL = 'https://docs.google.com/forms/d/1ROdwmjejeEYVJrjEL2R5AiZjY9rF6nhlxvMDj8SOZ0E/edit'; // 예: 'https://docs.google.com/forms/d/XXXX/edit'

const SEND_CONFIRMATION_EMAIL = true; // false면 메일 없이 배정표 기입만 (연락은 직접)
const CAPACITY = 2;
// 배정표 세션 1은 2026-09-27 파일럿(P001·P002)이 썼으므로 첫 슬롯은 세션 2부터.
const SESSION_OFFSET = 1;

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
      6: [17, 19],                 // 10/4 일
    },
  },
  {
    monday: new Date(2026, 9, 5), // 2026-10-05 (월)
    hours: {
      0: [9, 11, 13, 15, 17, 19],  // 10/5 월
      1: [9, 11, 13, 15, 17, 19],  // 10/6 화
      2: [9, 11, 18, 20],          // 10/7 수
      3: [18, 20],                 // 10/8 목
      4: [9],                      // 10/9 금 (한글날) 오전만
      5: [9, 11, 13, 15, 17, 19],  // 10/10 토
      6: [9, 11, 13, 15, 17, 19],  // 10/11 일
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
  '■ 참여 내용 (약 75분, 최대 85분): 연구 설명 및 동의(약 5분) → 사전 설문과 사전 지식 확인 문항(약 15분) → AI 챗봇으로 주어진 주제 학습(약 30분, 최대 35분) → 사후 설문(약 10분) → 사후 지식 확인 문항과 주관식 질문(약 15분)',
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
const Q_NAME = '이름';
const Q_CONTACT = '연락처 (전화번호 또는 카카오톡 아이디)';
const Q_AFFIL = '소속 (학과·학년, 예: 산업공학과 3학년)';
const Q_AGE = '만 19세 이상이신가요?';
const Q_BACKGROUND = '다음 분야의 전공·실무 경력·관련 자격증 보유 여부를 표시해 주세요. (해당 항목 모두)';
const BACKGROUND_ROWS = ['금융 / 핀테크', '컴퓨터 / 정보보안', '블록체인 / 암호화폐', '물류 / 공급망', '의료 / 보건'];
const BACKGROUND_COLS = ['전공', '실무 경력', '자격증', '해당 없음'];
const EXCLUDED_ROW = '블록체인 / 암호화폐';
const Q_RELATION = '연구책임자(백두산)에게 직접 지도를 받거나 평가를 받는 관계인가요? (수업 조교·지도 학생 등)';
const SLOT_QUESTION_TITLE = '희망 시간';
const SLOT_HELP = '남아 있는 시간만 표시됩니다. 각 슬롯은 2시간이며 실제 소요는 약 75분(최대 85분)입니다.';
const WAITLIST = '대기자로 등록 (빈자리가 나면 연락드립니다)';
const Q_CONFIRM = '확인';
const CONSENT_CHECK = '소요 시간(약 75분, 최대 85분)·장소·사례 안내를 확인했으며, 참여가 어려워지면 미리 연락하겠습니다.';

const DAY_NAMES = ['월', '화', '수', '목', '금', '토', '일'];
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
    .setCollectEmail(true)
    .setConfirmationMessage(CONFIRMATION_MESSAGE);

  ensureText_(form, Q_NAME);
  ensureText_(form, Q_CONTACT);
  ensureText_(form, Q_AFFIL);
  ensureChoice_(form, Q_AGE, ['예', '아니요']);
  ensureGrid_(form, Q_BACKGROUND, BACKGROUND_ROWS, BACKGROUND_COLS);
  ensureChoice_(form, Q_RELATION, ['예', '아니요']);
  const slot = ensureChoice_(form, SLOT_QUESTION_TITLE, [WAITLIST]);
  slot.setHelpText(SLOT_HELP);
  const confirm = findItem_(form, Q_CONFIRM, FormApp.ItemType.CHECKBOX);
  if (confirm) confirm.asCheckboxItem().setChoiceValues([CONSENT_CHECK]).setRequired(true);
  else form.addCheckboxItem().setTitle(Q_CONFIRM).setChoiceValues([CONSENT_CHECK]).setRequired(true);

  resetChoices();
  // 응답을 이 시트로 연결 (이미 다른 시트에 연결돼 있으면 이 시트로 바뀐다)
  form.setDestination(FormApp.DestinationType.SPREADSHEET, SpreadsheetApp.getActive().getId());
  installTrigger_(form);

  Logger.log('완료. 슬롯 %s개, 정원 %s명/슬롯', buildSlots_().length, CAPACITY);
  Logger.log('신청 링크: %s', form.getPublishedUrl());
  Logger.log('편집 링크: %s', form.getEditUrl());
  Logger.log('기존 문항 중 이 스크립트가 모르는 것은 그대로 남아 있습니다. 편집 링크에서 확인하세요.');
}

function findItem_(form, title, type) {
  return form.getItems(type).filter(i => i.getTitle() === title)[0] || null;
}
function ensureText_(form, title) {
  const it = findItem_(form, title, FormApp.ItemType.TEXT);
  return (it ? it.asTextItem() : form.addTextItem().setTitle(title)).setRequired(true);
}
function ensureChoice_(form, title, choices) {
  const it = findItem_(form, title, FormApp.ItemType.MULTIPLE_CHOICE);
  const mc = it ? it.asMultipleChoiceItem() : form.addMultipleChoiceItem().setTitle(title);
  if (!it || title !== SLOT_QUESTION_TITLE) mc.setChoiceValues(choices);
  return mc.setRequired(true);
}
function ensureGrid_(form, title, rows, cols) {
  const it = findItem_(form, title, FormApp.ItemType.CHECKBOX_GRID);
  const g = it ? it.asCheckboxGridItem() : form.addCheckboxGridItem().setTitle(title);
  return g.setRows(rows).setColumns(cols).setRequired(true);
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

/** "9/28(월) 09:00~11:00" 형식의 슬롯 목록. 시간순. */
function buildSlots_() {
  const out = [];
  SCHEDULE.forEach(week => {
    for (let d = 0; d < 7; d++) {
      const date = new Date(week.monday.getTime() + d * 86400000);
      (week.hours[d] || []).forEach(h => {
        const hh = String(h).padStart(2, '0');
        const end = String(h + 2).padStart(2, '0');
        out.push(`${date.getMonth() + 1}/${date.getDate()}(${DAY_NAMES[d]}) ${hh}:00~${end}:00`);
      });
    }
  });
  return out;
}

function slotItem_() {
  const it = findItem_(form_(), SLOT_QUESTION_TITLE, FormApp.ItemType.MULTIPLE_CHOICE);
  if (!it) throw new Error(`객관식 문항 "${SLOT_QUESTION_TITLE}"이 폼에 없습니다. applyIrbSettings를 실행하세요.`);
  return it.asMultipleChoiceItem();
}

/** 선택지를 SCHEDULE 기준으로 다시 채운다 (찬 슬롯은 제외). */
function resetChoices() {
  const counts = countBySlot_();
  const open = buildSlots_().filter(s => (counts[s] || 0) < CAPACITY);
  slotItem_().setChoiceValues([...open, WAITLIST]);
}

/** 적격 신청만 슬롯별로 센다. 대기자는 세지 않는다. */
function countBySlot_() {
  const counts = {};
  form_().getResponses().forEach(r => {
    if (!eligibility_(r).ok) return;
    r.getItemResponses().forEach(ir => {
      if (ir.getItem().getTitle() !== SLOT_QUESTION_TITLE) return;
      const v = String(ir.getResponse());
      if (v === WAITLIST) return;
      counts[v] = (counts[v] || 0) + 1;
    });
  });
  return counts;
}

/** 현황 (실행 로그). */
function status() {
  const counts = countBySlot_();
  buildSlots_().forEach((s, i) =>
    Logger.log('세션 %s  %s  %s/%s', i + 1 + SESSION_OFFSET, s, counts[s] || 0, CAPACITY));
}

// ── 스크리닝 ─────────────────────────────────────────────────────────

/** IRB 선정·제외 기준 충족 여부. 사유는 내부 기록용(참가자에게 보내지 않음). */
function eligibility_(response) {
  let age = null, relation = null, bg = null;
  response.getItemResponses().forEach(ir => {
    const t = ir.getItem().getTitle();
    if (t === Q_AGE) age = String(ir.getResponse());
    if (t === Q_RELATION) relation = String(ir.getResponse());
    if (t === Q_BACKGROUND) bg = ir.getResponse(); // 행별 배열
  });
  if (age === '아니요') return { ok: false, reason: '만 19세 미만' };
  if (relation === '예') return { ok: false, reason: '연구자와 지도·평가 관계' };
  if (bg) {
    const idx = BACKGROUND_ROWS.indexOf(EXCLUDED_ROW);
    const cells = [].concat(bg[idx] || []).filter(v => v && v !== '해당 없음');
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
  const chosen = answers[SLOT_QUESTION_TITLE] ? String(answers[SLOT_QUESTION_TITLE]) : null;
  const email = response.getRespondentEmail();

  // 1. 찬 슬롯을 선택지에서 뺀다.
  const item = slotItem_();
  const counts = countBySlot_();
  const remaining = item.getChoices().map(c => c.getValue())
    .filter(v => v === WAITLIST || (counts[v] || 0) < CAPACITY);
  if (remaining.length !== item.getChoices().length) item.setChoiceValues(remaining);

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
    pid = assignSeat_(chosen, String(answers[Q_NAME] || '').trim(), String(answers[Q_CONTACT] || '').trim());
  }

  // 4. 확정 메일.
  if (!SEND_CONFIRMATION_EMAIL || !email || !chosen) return;
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
        '소요 시간: 약 75분, 최대 85분 (컴퓨터 준비되어 있음, 준비물 없음)',
        '사례: 전 과정 완료 시 15,000원 (중단 시에도 참여 시간에 따라 지급)',
        '',
        '시작 시각에 맞춰 도착해 주세요. 참여가 어려워지면 미리 알려 주시면 다른 분께 기회가 갑니다.',
        '', CONTACT_LINE,
      ];
  MailApp.sendEmail(email, subject, body.filter(l => l !== null).join('\n'));
}

/** 배정표에서 해당 세션의 빈 좌석에 이름을 적고 참여자 번호를 돌려준다 (없으면 null). */
function assignSeat_(slotLabel, name, contact) {
  const idx = buildSlots_().indexOf(slotLabel);
  if (idx < 0 || !name) return null;
  const session = idx + 1 + SESSION_OFFSET;
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
    });
    if (col.session != null && col.pid != null && col.name != null) h = r;
  }
  if (h < 0) return null;
  for (let i = h + 1; i < rows.length; i++) {
    if (Number(rows[i][col.session]) !== session) continue;
    if (String(rows[i][col.name] || '').trim()) continue;
    sheet.getRange(i + 1, col.name + 1).setValue(name);
    if (col.note != null && !rows[i][col.note]) {
      sheet.getRange(i + 1, col.note + 1).setValue(contact ? `${slotLabel} · ${contact}` : slotLabel);
    }
    return String(rows[i][col.pid]);
  }
  return null;
}
