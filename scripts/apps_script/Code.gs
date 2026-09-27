/**
 * 실험운영 시트용 Apps Script — 참가자 조회 + 세션 기록 + 내보내기 백업.
 *
 * 설치 (1회):
 *   1. 시트에서 확장 프로그램 → Apps Script → 이 파일 내용을 Code.gs에 붙여 넣기
 *   2. 배포 → 새 배포 → 유형 "웹 앱"
 *        - 실행 사용자: 나
 *        - 액세스 권한: 모든 사용자(익명 포함)
 *   3. 웹 앱 URL(https://script.google.com/macros/s/…/exec)을 앱 빌드에 전달:
 *        --dart-define=REGISTRY_URL=<웹 앱 URL>
 *   스크립트를 고치면 "배포 관리 → 새 버전"으로 다시 배포해야 반영된다.
 *
 * 시트 구조:
 *   [배정표] 헤더 행(기본 5행)에 다음 열 이름이 있으면 순서와 무관하게 찾는다.
 *       "참여자 번호"(필수) · "조건"(필수: 처치/비교, treatment/control, A/B)
 *       "이름"(있으면 이름까지 대조) · "사용 여부"(불참이면 시작 차단, 시작 시 '사용' 기록)
 *       "실시 날짜"(시작 시 오늘 날짜 기록)
 *   [세션기록] 헤더 행(1~5행 중 "참여자 번호"가 있는 행)을 찾아 참가자 행에 쓴다:
 *       시작 시 "학습 시작"(HH:MM), 저장 시 "학습 종료"(HH:MM)와 "특이사항"(오류/재시도/백업 링크).
 *       "날짜"가 비어 있으면 함께 채운다. 참가자 행이 없으면 맨 아래에 요약 행을 붙인다.
 *   Drive 폴더 "실험 세션 백업": 내보내기 JSON 전문을 저장한다 (없으면 만든다)
 *
 * 요청:
 *   GET  ?action=lookup&pid=P007&name=홍길동  → {ok:true, condition:"treatment"} | {ok:false, reason:"not_found"}
 *   GET  ?action=start&pid=&name=&condition=&startedAt=  → 세션기록에 시작 행 추가 + 배정표 실시 날짜/사용 여부 기록
 *   POST body=JSON(내보내기 파일 전문), Content-Type text/plain → Drive 저장 + 세션기록 요약 행 추가
 */

const ASSIGNMENT_SHEET = '배정표';
const LOG_SHEET = '세션기록';
const BACKUP_FOLDER = '실험 세션 백업';

/**
 * 권한 승인용. 편집기에서 이 함수를 선택해 ▶ 실행하면 시트·Drive 권한 승인 창이 뜬다.
 * 승인 후 "배포 관리 → 새 버전"으로 다시 배포해야 웹 앱에 반영된다.
 * (2026-09-27: Drive 권한 없이 배포돼 내보내기 백업이 전부 실패했다.)
 */
function authorize() {
  SpreadsheetApp.getActive().getName();
  const f = folder_();
  Logger.log('권한 OK. 백업 폴더: %s', f.getUrl());
}

/**
 * 분석용 읽기 토큰 발급. 편집기에서 ▶ 실행 → 로그에 찍힌 토큰을 분석자에게 전달.
 * 토큰은 스크립트 속성에만 저장된다 (코드·저장소에 남지 않음). 다시 실행하면 새 토큰으로 교체.
 */
function makeReadToken() {
  const token = Utilities.getUuid().replace(/-/g, '');
  PropertiesService.getScriptProperties().setProperty('READ_TOKEN', token);
  Logger.log('READ_TOKEN: %s', token);
}

/** 토큰이 맞을 때만 탭 내용을 돌려준다. ?action=read&token=…&sheet=탭이름 (sheet 없으면 탭 목록). */
function read_(p) {
  const expected = PropertiesService.getScriptProperties().getProperty('READ_TOKEN');
  if (!expected || p.token !== expected) return { ok: false, reason: 'unauthorized' };
  const ss = SpreadsheetApp.getActive();
  if (!p.sheet) {
    return { ok: true, sheets: ss.getSheets().map(sh => ({ name: sh.getName(), rows: sh.getLastRow(), cols: sh.getLastColumn() })) };
  }
  const sh = ss.getSheetByName(p.sheet);
  if (!sh) return { ok: false, reason: 'no_sheet' };
  const values = sh.getDataRange().getDisplayValues();
  return { ok: true, sheet: p.sheet, values: values };
}

function doGet(e) {
  const p = (e && e.parameter) || {};
  try {
    switch (p.action) {
      case 'lookup':
        return json_(lookup_(p.pid, p.name));
      case 'start':
        markStarted_(p.pid);
        logSession_(p.pid, {
          '학습 시작': hhmm_(p.startedAt),
          '날짜': dateOnly_(p.startedAt),
        }, [
          new Date(), 'start', norm_(p.pid), norm_(p.name), p.condition || '',
          p.startedAt || '', '', '', '', '', '',
        ]);
        return json_({ ok: true });
      case 'read':
        return json_(read_(p));
      case 'ping':
        return json_({ ok: true, time: new Date().toISOString() });
      default:
        return json_({ ok: false, reason: 'unknown_action' });
    }
  } catch (err) {
    return json_({ ok: false, reason: 'error', message: String(err) });
  }
}

function doPost(e) {
  try {
    const body = e.postData && e.postData.contents;
    if (!body) return json_({ ok: false, reason: 'empty' });
    const data = JSON.parse(body);
    const participant = data.participant || {};
    const experiment = data.experiment || {};
    const summary = data.summary || {};
    const calls = summary.llmCalls || {};
    const pid = norm_(participant.name);
    const name = norm_(participant.displayName);

    const stamp = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm');
    const filename = [stamp, experiment.condition || 'unknown', pid || 'session'].join('_') + '.json';
    const file = folder_().createFile(filename, body, 'application/json');

    const note = '턴 ' + (summary.turnCount || 0) +
      ' · 오류 ' + (summary.errors || 0) +
      ' · 재시도 ' + (calls.retried || 0) +
      ' · 백업 ' + file.getUrl();
    logSession_(pid, {
      '학습 종료': hhmm_(participant.endedAt),
      '날짜': dateOnly_(participant.startedAt),
      '특이사항': note,
    }, [
      new Date(), 'export', pid, name, experiment.condition || '',
      participant.startedAt || '', participant.endedAt || '',
      Math.round((participant.totalDurationMs || 0) / 1000),
      summary.turnCount || 0,
      (summary.errors || 0) + ' / ' + (calls.retried || 0),
      file.getUrl(),
    ]);
    return json_({ ok: true, fileUrl: file.getUrl() });
  } catch (err) {
    return json_({ ok: false, reason: 'error', message: String(err) });
  }
}

/** 배정표에서 헤더 행과 열 위치를 찾는다. */
function assignmentTable_() {
  const sheet = SpreadsheetApp.getActive().getSheetByName(ASSIGNMENT_SHEET);
  if (!sheet) return null;
  const rows = sheet.getDataRange().getValues();
  for (let r = 0; r < Math.min(rows.length, 20); r++) {
    const cols = {};
    rows[r].forEach((cell, c) => {
      const h = String(cell || '').replace(/\s+/g, '');
      if (h === '참여자번호' || h === '참가자번호') cols.pid = c;
      else if (h === '조건') cols.condition = c;
      else if (h === '이름') cols.name = c;
      else if (h === '사용여부') cols.used = c;
      else if (h === '실시날짜') cols.date = c;
    });
    if (cols.pid != null && cols.condition != null) {
      return { sheet: sheet, rows: rows, headerRow: r, cols: cols };
    }
  }
  return null;
}

/** 번호(+이름 열이 있으면 이름)가 배정표와 일치하면 조건을 돌려준다. */
function lookup_(pid, name) {
  const key = norm_(pid);
  if (!key) return { ok: false, reason: 'missing' };
  const t = assignmentTable_();
  if (!t) return { ok: false, reason: 'no_sheet' };

  for (let i = t.headerRow + 1; i < t.rows.length; i++) {
    const row = t.rows[i];
    if (norm_(row[t.cols.pid]) !== key) continue;
    if (t.cols.name != null && norm_(row[t.cols.name]) !== norm_(name)) {
      return { ok: false, reason: 'name_mismatch' };
    }
    if (t.cols.used != null && norm_(row[t.cols.used]) === '불참') {
      return { ok: false, reason: 'unavailable' };
    }
    const condition = normalizeCondition_(row[t.cols.condition]);
    if (!condition) return { ok: false, reason: 'no_condition' };
    return { ok: true, condition: condition, pid: key, sheetRow: i + 1 };
  }
  return { ok: false, reason: 'not_found' };
}

/** 시작 시 배정표의 실시 날짜·사용 여부를 채운다 (비어 있을 때만). */
function markStarted_(pid) {
  const t = assignmentTable_();
  if (!t) return;
  const key = norm_(pid);
  for (let i = t.headerRow + 1; i < t.rows.length; i++) {
    if (norm_(t.rows[i][t.cols.pid]) !== key) continue;
    const rowNumber = i + 1;
    if (t.cols.date != null && !t.rows[i][t.cols.date]) {
      t.sheet.getRange(rowNumber, t.cols.date + 1).setValue(new Date());
    }
    if (t.cols.used != null && !t.rows[i][t.cols.used]) {
      t.sheet.getRange(rowNumber, t.cols.used + 1).setValue('사용');
    }
    return;
  }
}

function normalizeCondition_(v) {
  const s = String(v || '').trim().toLowerCase();
  if (['treatment', 'addie', 'a', '처치', '처치군', '처치조건'].includes(s)) return 'treatment';
  if (['control', 'freeform', 'free', 'b', '대조', '대조군', '비교', '비교군', '비교조건'].includes(s)) return 'control';
  return null;
}

function norm_(v) {
  return String(v == null ? '' : v).replace(/\s+/g, '').trim().toUpperCase();
}

/**
 * 세션기록 탭의 참가자 행에 값을 쓴다. 헤더 이름으로 열을 찾으므로 열 순서는 무관.
 * 참가자 행이나 헤더를 못 찾으면 [fallbackRow]를 맨 아래에 붙인다.
 * 비어 있는 셀만 채운다 — 진행자가 손으로 적은 값을 덮어쓰지 않는다.
 * 단, "특이사항"은 기존 내용 뒤에 이어 붙인다.
 */
function logSession_(pid, values, fallbackRow) {
  const ss = SpreadsheetApp.getActive();
  let sheet = ss.getSheetByName(LOG_SHEET);
  if (!sheet) {
    sheet = ss.insertSheet(LOG_SHEET);
    sheet.appendRow([
      '기록 시각', '이벤트', '참가자 번호', '이름', '조건',
      '시작 시각', '종료 시각', '소요(초)', '턴 수', '오류 / 재시도', '백업 파일',
    ]);
    sheet.appendRow(fallbackRow);
    return;
  }
  const rows = sheet.getDataRange().getValues();
  let headerRow = -1;
  const cols = {};
  for (let r = 0; r < Math.min(rows.length, 10) && headerRow < 0; r++) {
    rows[r].forEach((cell, c) => {
      const h = String(cell || '').replace(/\s+/g, '');
      if (h === '참여자번호' || h === '참가자번호') { headerRow = r; cols.pid = c; }
    });
    if (headerRow >= 0) {
      rows[r].forEach((cell, c) => {
        const h = String(cell || '').replace(/\s+/g, '');
        Object.keys(values).forEach(k => {
          if (h === k.replace(/\s+/g, '')) cols[k] = c;
        });
      });
    }
  }
  if (headerRow < 0) { sheet.appendRow(fallbackRow); return; }

  const key = norm_(pid);
  for (let i = headerRow + 1; i < rows.length; i++) {
    if (norm_(rows[i][cols.pid]) !== key) continue;
    Object.keys(values).forEach(k => {
      if (cols[k] == null || values[k] === '' || values[k] == null) return;
      const cell = sheet.getRange(i + 1, cols[k] + 1);
      const current = rows[i][cols[k]];
      if (k === '특이사항') {
        cell.setValue(current ? current + ' | ' + values[k] : values[k]);
      } else if (!current) {
        cell.setValue(values[k]);
      }
    });
    return;
  }
  sheet.appendRow(fallbackRow);
}

function hhmm_(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return Utilities.formatDate(d, Session.getScriptTimeZone(), 'HH:mm');
}

function dateOnly_(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
}

function folder_() {
  const it = DriveApp.getFoldersByName(BACKUP_FOLDER);
  return it.hasNext() ? it.next() : DriveApp.createFolder(BACKUP_FOLDER);
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
