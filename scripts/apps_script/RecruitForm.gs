/**
 * 참가자 모집 폼용 Apps Script — 슬롯별 정원(2명) 선착순 자동 마감 + 확정 메일.
 * CONTACT_LINE에 연락처를 적은 뒤 설치한다.
 *
 * 설치 (1회, 구글 폼에서):
 *   1. 폼 편집 화면 → 우측 상단 ⋮ → 스크립트 편집기 → 이 파일 내용을 Code.gs에 붙여 넣기
 *   2. 폼 설정 → 응답 → "이메일 주소 수집"을 켠다 (확정 메일용). 안 켜면 메일만 생략된다.
 *   3. 폼에 객관식 문항 "희망 시간"을 만든다 (제목은 SLOT_QUESTION_TITLE과 같아야 함).
 *      선택지는 비워 두고 아래 4번이 채운다.
 *   4. 편집기에서 함수 `setup`을 선택해 ▶ 실행 → 권한 승인.
 *      → 선택지가 SLOTS로 채워지고, 응답 제출 시 `onSubmit`이 돌도록 트리거가 걸린다.
 *
 * 동작:
 *   - 응답이 들어올 때마다 슬롯별 인원을 세서 CAPACITY명이 찬 슬롯을 선택지에서 뺀다.
 *   - 대기자 선택지(WAITLIST)는 절대 빼지 않는다.
 *   - 이메일을 수집하면 신청자에게 확정(또는 대기 등록) 메일을 보낸다.
 *   - 슬롯을 바꾸려면 SCHEDULE을 고치고 `resetChoices`를 실행한다 (찬 슬롯은 자동 제외).
 *
 * 같은 슬롯에 거의 동시에 제출되면 정원을 넘길 수 있다. 응답 시트에서 보이니
 * 늦은 쪽에 다른 시간을 제안한다.
 */

const SLOT_QUESTION_TITLE = '희망 시간';
const CAPACITY = 2;
const WAITLIST = '대기자로 등록 (빈자리가 나면 연락드립니다)';

// 실험 주 일정. 주마다 월요일 날짜와 요일별 시작 시각(0=월 … 6=일)을 적는다.
// 각 슬롯은 2시간 (19 = 19:00~21:00). 주를 추가하려면 항목을 하나 더 넣는다.
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

const DAY_NAMES = ['월', '화', '수', '목', '금', '토', '일'];

/** SLOTS: "9/28(월) 09:00~11:00" 형식의 선택지 목록. 시간순. */
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

const LOCATION_LINE = '장소: 서울대학교 39동 336호 산업/인간공학 실험실';
const CONTACT_LINE = '문의: ___';

/** 1회 실행: 선택지 채우기 + 제출 트리거 설치. */
function setup() {
  resetChoices();
  const form = FormApp.getActiveForm();
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'onSubmit')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('onSubmit').forForm(form).onFormSubmit().create();
  Logger.log('설치 완료. 슬롯 %s개, 정원 %s명/슬롯', buildSlots_().length, CAPACITY);
}

/** 선택지를 SLOTS 기준으로 다시 채운다 (이미 찬 슬롯은 제외). */
function resetChoices() {
  const item = slotItem_();
  const counts = countBySlot_();
  const open = buildSlots_().filter(s => (counts[s] || 0) < CAPACITY);
  item.setChoiceValues([...open, WAITLIST]);
}

/** 응답 제출 시: 찬 슬롯 제거 + 확정 메일. */
function onSubmit(e) {
  const response = e && e.response;
  let chosen = null;
  if (response) {
    response.getItemResponses().forEach(ir => {
      if (ir.getItem().getTitle() === SLOT_QUESTION_TITLE) chosen = String(ir.getResponse());
    });
  }

  // 1. 정원이 찬 슬롯을 선택지에서 뺀다.
  const item = slotItem_();
  const counts = countBySlot_();
  const remaining = item.getChoices()
    .map(c => c.getValue())
    .filter(v => v === WAITLIST || (counts[v] || 0) < CAPACITY);
  if (remaining.length !== item.getChoices().length) item.setChoiceValues(remaining);

  // 2. 확정 메일 (이메일 수집이 켜져 있을 때만).
  const email = response && response.getRespondentEmail();
  if (!email || !chosen) return;
  const isWaitlist = chosen === WAITLIST;
  const subject = isWaitlist
    ? '[AI 튜터 학습 실험] 대기자 등록 안내'
    : `[AI 튜터 학습 실험] 참여 확정: ${chosen}`;
  const body = isWaitlist
    ? [
        '대기자로 등록되었습니다. 빈자리가 나면 순서대로 연락드리겠습니다.',
        '', CONTACT_LINE,
      ].join('\n')
    : [
        `참여가 확정되었습니다.`,
        '',
        `일시: ${chosen}`,
        LOCATION_LINE,
        '소요 시간: 약 1시간 10분 (컴퓨터 준비되어 있음, 준비물 없음)',
        '사례비: 15,000원 (참여 완료 시 지급)',
        '',
        '시작 시각에 맞춰 도착해 주세요. 10분 이상 늦으면 참여가 어려울 수 있습니다.',
        '참여가 어려워지면 미리 알려 주시면 다른 분께 기회가 갑니다.',
        '', CONTACT_LINE,
      ].join('\n');
  MailApp.sendEmail(email, subject, body);
}

/** 슬롯별 응답 수. 대기자 선택은 세지 않는다. */
function countBySlot_() {
  const form = FormApp.getActiveForm();
  const counts = {};
  form.getResponses().forEach(r => {
    r.getItemResponses().forEach(ir => {
      if (ir.getItem().getTitle() !== SLOT_QUESTION_TITLE) return;
      const v = String(ir.getResponse());
      if (v === WAITLIST) return;
      counts[v] = (counts[v] || 0) + 1;
    });
  });
  return counts;
}

function slotItem_() {
  const form = FormApp.getActiveForm();
  const items = form.getItems(FormApp.ItemType.MULTIPLE_CHOICE)
    .filter(i => i.getTitle() === SLOT_QUESTION_TITLE);
  if (items.length === 0) {
    throw new Error(`객관식 문항 "${SLOT_QUESTION_TITLE}"이 폼에 없습니다.`);
  }
  return items[0].asMultipleChoiceItem();
}

/** 현재 슬롯별 현황을 로그로 본다 (편집기에서 실행). */
function status() {
  const counts = countBySlot_();
  buildSlots_().forEach(s => Logger.log('%s  %s/%s', s, counts[s] || 0, CAPACITY));
}
