/**
 * QuickAdd Macro Script
 * 目的：
 * - アクティブmdの「> [!todo] **==■■■■■ 【更改】 ■■■■■==**」行より下を対象に、
 * 次のcallout（> [!xxx]）直前まで（無ければ末尾まで）を並べ替える
 * - 並べ替え①：MM/DD 昇順（同一日付は安定ソート）
 * - 並べ替え②：会社名でグルーピングし、2行目以降は半角スペース4つインデント
 * - 【追加】現在日からの日数に応じて日付をハイライト（20日:白赤, 30日:赤, 45日:オレンジ, 60日:緑）
 *
 * 使い方：
 * - QuickAdd > Macro > Script に貼り付けて実行
 */

module.exports = async (params) => {
  const app = params.app;

  const file = app.workspace.getActiveFile();
  if (!file) {
    new Notice("アクティブなファイルがありません。");
    return;
  }

  const original = await app.vault.read(file);

  // --- 1) 開始マーカーを探す
  const markerRe = /^(>\s*\[!todo\].*【更改】.*)$/m;
  const markerMatch = original.match(markerRe);

  if (!markerMatch || markerMatch.index == null) {
    new Notice("開始マーカー（> [!todo] ...【更改】...）が見つかりません。");
    return;
  }

  const markerLineStart = markerMatch.index;
  const markerLineEnd = original.indexOf("\n", markerLineStart);
  const startPos = markerLineEnd === -1 ? original.length : markerLineEnd + 1;

  // --- 2) 終了位置（次の callout）を探す
  const after = original.slice(startPos);
  const nextCalloutRe = /^(>\s*\[![^\]]+\].*)$/m;
  const nextCalloutMatch = after.match(nextCalloutRe);

  const endPos = nextCalloutMatch && nextCalloutMatch.index != null
    ? startPos + nextCalloutMatch.index
    : original.length;

  const beforeBlock = original.slice(0, startPos);
  const targetBlock = original.slice(startPos, endPos);
  const afterBlock = original.slice(endPos);


  // --- 【新規】日付フォーマット用のヘルパー関数 ---
  function getStyledDateStr(month, day) {
    const now = new Date();
    // 時刻を無視して「今日」の日付をセット
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    
    // タスクの日付（年は今年と仮定）
    let target = new Date(now.getFullYear(), month - 1, day);

    // 差分日数を計算
    let diffDays = (target - today) / (1000 * 60 * 60 * 24);

    // ※もし過去半年以上前の日付なら「来年の更改タスク」とみなして年を+1する処理
    if (diffDays < -180) {
      target = new Date(now.getFullYear() + 1, month - 1, day);
      diffDays = (target - today) / (1000 * 60 * 60 * 24);
    }

    const dateStr = `${month}/${day}`;

    // 条件に応じてHTMLのspanタグで装飾
    // ※ 期限切れ（diffDaysがマイナス）の場合も「20日以内」の条件に合致し、一番強い赤色になります
    if (diffDays <= 20) {
      return `<span style="color: white; background-color: red; font-weight: bold;">${dateStr}</span>`;
    } else if (diffDays <= 30) {
      return `<span style="color: red; font-weight: bold;">${dateStr}</span>`;
    } else if (diffDays <= 45) {
      return `<span style="color: orange; font-weight: bold;">${dateStr}</span>`;
    } else if (diffDays <= 60) {
      return `<span style="color: green; font-weight: bold;">${dateStr}</span>`;
    } else {
      return dateStr; // 61日以上先は装飾なし
    }
  }


  // --- 3) 対象行を抽出・パース
  const lines = targetBlock.split("\n");
  const taskRe = /^\s*-\s*\[([ xX\-\/])\]\s*(.+)\s*$/;

  // 【修正】すでにHTMLタグ(span等)で色付けされていても、タグを無視して日付を抽出できる正規表現
  const bodyRe = /^(.+?)_\s*(?:<[^>]+>)*\s*(\d{1,2})\/(\d{1,2})\s*(?:<[^>]+>)*\s*_(.+)$/;

  const items = [];
  const passthrough = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const mTask = line.match(taskRe);
    if (!mTask) {
      passthrough.push(line);
      continue;
    }

    const status = mTask[1];
    const rawBody = mTask[2];
    const mBody = rawBody.match(bodyRe);

    if (!mBody) {
      passthrough.push(line);
      continue;
    }

    const company = mBody[1];
    const month = parseInt(mBody[2], 10);
    const day = parseInt(mBody[3], 10);
    const rest = mBody[4]; // 商品名＋保険料など

    // 【新規】現在日基準で色付けされた日付文字列を取得し、行を再構築
    const styledDate = getStyledDateStr(month, day);
    const newBody = `${company}_${styledDate}_${rest}`;

    items.push({
      status,
      company,
      month,
      day,
      body: newBody,
      originalIndex: i
    });
  }

  if (items.length === 0) {
    new Notice("並べ替え対象の行（会社名_MM/DD_...）が見つかりません。");
    return;
  }

  // --- 4) 並べ替え①：日付昇順
  items.sort((a, b) => {
    if (a.month !== b.month) return a.month - b.month;
    if (a.day !== b.day) return a.day - b.day;
    return a.originalIndex - b.originalIndex;
  });

  // --- 5) 並べ替え②：会社名でグルーピング
  const groupMap = new Map();
  const groupOrder = [];

  for (const it of items) {
    if (!groupMap.has(it.company)) {
      groupMap.set(it.company, []);
      groupOrder.push(it.company);
    }
    groupMap.get(it.company).push(it);
  }

  // --- 6) 出力生成
  const INDENT = "    ";
  const out = [];
  for (const company of groupOrder) {
    const g = groupMap.get(company);

    g.forEach((it, idx) => {
      const prefix = idx === 0 ? "" : INDENT;
      out.push(`${prefix}- [${it.status}] ${it.body}`);
    });
  }

  // 空行クリーニングと結合
  const validPassthrough = passthrough.filter(line => line.trim() !== "");
  const passthroughText = validPassthrough.length > 0 ? "\n" + validPassthrough.join("\n") : "";

  let newBlock = out.join("\n") + passthroughText;

  // 次のCalloutとの連結防止
  if (afterBlock.length > 0 && !newBlock.endsWith("\n")) {
    newBlock += "\n";
  }

  // --- 7) 書き戻し
  const updated = beforeBlock + newBlock + afterBlock;
  if (updated === original) {
    new Notice("変更点がありません。");
    return;
  }

  await app.vault.modify(file, updated);
  new Notice("更改リストの並べ替えと期限のハイライトを更新しました。");
};