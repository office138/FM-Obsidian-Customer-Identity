/**
 * QuickAdd Script: Move completed tasks from "実行中タスクブロック" and "【更改】" to "終了タスクブロック"
 * - 完了タスク（取り消し線 or - [x]）を移動
 * - 更改ブロックに完了タスクがある場合、QuickAddのダイアログで移動するか確認
 * - 「移動した終了タスクの前の空行」は作らない
 * - 「終了タスクブロック」と「実行中タスクブロック」の間は空行2行を必ず確保
 * - タスクが抜けた後の不要な空行は自動で詰める
 */

module.exports = async (params) => {
  const { app, quickAddApi } = params; // quickAddApiを追加取得
  const Notice = app?.constructor?.Notice || window.Notice;

  const file = app.workspace.getActiveFile();
  if (!file) {
    new Notice("アクティブなノートがありません。タスク管理ノートを開いてから実行してください。");
    return;
  }

  const text = await app.vault.read(file);
  const lines = text.split("\n");

  // --- ブロック見出しの特定（部分一致で頑強に）
  const isEndHeader = (l) => l.includes("【終了タスク】") && l.includes("[!quote]");
  const isRunHeader = (l) => l.includes("【実行中タスク】") && l.includes("[!todo]");
  const isKokaiHeader = (l) => l.includes("【更改】") && l.includes("[!todo]");

  const endHeaderIdx = lines.findIndex(isEndHeader);
  const runHeaderIdx = lines.findIndex(isRunHeader);
  const kokaiHeaderIdx = lines.findIndex(isKokaiHeader);

  if (endHeaderIdx === -1 || runHeaderIdx === -1) {
    new Notice("ブロック見出し（終了タスク / 実行中タスク）が見つかりません。見出し行を確認してください。");
    return;
  }

  const endBlockStart = endHeaderIdx + 1;
  const runBlockStart = runHeaderIdx + 1;
  const runBlockEnd = (kokaiHeaderIdx !== -1 ? kokaiHeaderIdx - 1 : lines.length - 1);

  // --- 完了タスクの判定関数
  const isCompletedTaskLine = (l) => {
    const taskDone = /^\s*[-*]\s+\[x\]\s+/i.test(l); // - [x]
    const hasStrike = l.includes("~~");              // 取り消し線
    return taskDone || hasStrike;
  };

  // ==========================================
  // 1. 実行中タスクブロックの処理
  // ==========================================
  const runCompleted = [];
  const remainingRun = [];

  if (runBlockStart <= runBlockEnd) {
    for (let i = runBlockStart; i <= runBlockEnd; i++) {
      const l = lines[i];
      if (isCompletedTaskLine(l) && l.trim() !== "") {
        runCompleted.push(l);
      } else {
        remainingRun.push(l);
      }
    }
  }

  // ==========================================
  // 2. 更改ブロックの処理（見出し次行〜最終行）
  // ==========================================
  const kokaiCompleted = [];
  const remainingKokai = [];
  const originalKokaiBlock = [];

  if (kokaiHeaderIdx !== -1) {
    const kokaiBlockStart = kokaiHeaderIdx + 1;
    let previousLineWasEmpty = false;

    for (let i = kokaiBlockStart; i < lines.length; i++) {
      const l = lines[i];
      originalKokaiBlock.push(l);

      if (isCompletedTaskLine(l) && l.trim() !== "") {
        kokaiCompleted.push(l);
      } else {
        const isEmpty = l.trim() === "";
        // タスクが抜けたことによる不自然な連続空行を防ぐ（詰める処理）
        if (isEmpty && previousLineWasEmpty) continue; 
        // ブロック先頭が空行になるのを防ぐ
        if (isEmpty && remainingKokai.length === 0) continue;

        remainingKokai.push(l);
        previousLineWasEmpty = isEmpty;
      }
    }

    // ブロック末尾の余分な空行を削除
    while (remainingKokai.length > 0 && remainingKokai[remainingKokai.length - 1].trim() === "") {
      remainingKokai.pop();
    }
  }

  // ==========================================
  // 3. 全体の移動対象チェック
  // ==========================================
  if (runCompleted.length === 0 && kokaiCompleted.length === 0) {
    new Notice("実行中ブロックおよび更改ブロックに、移動対象の完了タスクがありませんでした。");
    return;
  }

  // ==========================================
  // 4. 更改タスクの移動確認プロンプト
  // ==========================================
  let finalCompleted = [...runCompleted];
  let finalKokaiLines = kokaiHeaderIdx !== -1 ? originalKokaiBlock : [];
  let isKokaiMoved = false;

  if (kokaiCompleted.length > 0) {
    // QuickAddのAPIを使ってYes/Noダイアログを表示
    const shouldMoveKokai = await quickAddApi.yesNoPrompt(
      "タスク移動の確認", 
      "更改の完了タスクも上部の「終了タスク領域」へ移動しますか？"
    );

    if (shouldMoveKokai) {
      isKokaiMoved = true;
      // 順番：1.実行中タスクの完了分 → 2.更改の完了分
      finalCompleted = [...runCompleted, ...kokaiCompleted];
      finalKokaiLines = remainingKokai;
    }
  }

  // 実行中タスクが0件で、かつ更改タスクの移動をキャンセルした場合
  if (finalCompleted.length === 0) {
    new Notice("タスクの移動をキャンセルしました（実行中ブロックに完了タスクはありません）。");
    return;
  }

  // ==========================================
  // 5. 終了タスクブロックの構築
  // ==========================================
  let endBlockLines = lines.slice(endBlockStart, runHeaderIdx);

  // 末尾の空行を全削除（後で空行2行に揃えるため）
  while (endBlockLines.length > 0 && endBlockLines[endBlockLines.length - 1].trim() === "") {
    endBlockLines.pop();
  }

  // 完了タスクを追記（直前に空行は入れない）
  endBlockLines.push(...finalCompleted);

  // 終了タスクブロックと実行中タスクブロックの間：空行2行を必ず確保
  while (endBlockLines.length > 0 && endBlockLines[endBlockLines.length - 1].trim() === "") {
    endBlockLines.pop();
  }
  endBlockLines.push("", "");

  // ==========================================
  // 6. 新しい全文を組み立てて保存
  // ==========================================
  const newLines = [
    ...lines.slice(0, endBlockStart),
    ...endBlockLines,
    ...lines.slice(runHeaderIdx, runBlockStart), // 実行中見出し行
    ...remainingRun
  ];

  // 更改ブロックが存在する場合は末尾に結合
  if (kokaiHeaderIdx !== -1) {
    newLines.push(lines[kokaiHeaderIdx]); // 更改見出し行
    if (finalKokaiLines.length > 0) {
      newLines.push(...finalKokaiLines);
    }
  }

  await app.vault.modify(file, newLines.join("\n"));

  // 結果の通知
  let noticeMsg = `完了タスクを終了タスクへ移動しました。\n`;
  noticeMsg += `▶ 実行中タスクから: ${runCompleted.length}件\n`;
  if (kokaiHeaderIdx !== -1) {
    noticeMsg += `▶ 更改から: ${isKokaiMoved ? kokaiCompleted.length : 0}件`;
  }
  new Notice(noticeMsg);
};