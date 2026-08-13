// create-running-task-file.js
//
// =====================================================================
// 【概要】
//   QuickAdd の Macro から実行するスクリプト。
//   指定ユーザーのタスク管理フォルダにある「最新の【実行中】ファイル」を
//   複製して、翌日分（または本日分）の新しい【実行中】ファイルを作成する。
//   あわせて、過去30日ぶんの【予定】ファイルを本文末尾に取り込み、
//   取り込み済みの【予定】ファイルと旧【実行中】ファイルを履歴フォルダへ退避する。
//
// 【処理の流れ】
//   1) 対象ユーザーを選択
//   2) 対象フォルダ内の【実行中】ファイルを収集
//   3) 最新1件(sourceRunningFile)を特定し、新規ファイルの日付を決定
//   4) 過去30日ぶんの【予定】ファイルを収集
//   5) 本文を組み立て（最新1件＋予定）
//   6) 新規【実行中】ファイルを作成してアクティブ化
//   7) 【予定】ファイルを履歴へ退避
//   8) 旧【実行中】ファイルを履歴へ退避
//   9) 完了通知（移動失敗があれば警告付き）
//
// 【重複不具合への対策（重要）】
//   - 本文は「最新1件(sourceRunningFile)」のみから作る（全件連結はしない）。
//   - 本文に使わなかった旧【実行中】(otherRunningFiles)も必ず履歴退避する。
//     → 「本文生成で読む集合」と「履歴退避する集合」を一致させることで、
//       旧ファイルが残置され次回に再連結される累積重複を防ぐ。
//
// 【安全設計】
//   - ファイル読み込み失敗時は例外を伝播し、作成・退避を行わず中断する。
//   - 日付形式外の【実行中】ファイルがある場合は中断する。
//   - 履歴フォルダの用意は ensureArchiveFolder() で安全化（作成失敗・同名ファイルを検知）。
//   - 前日ファイルに残る予定案内文(PLAN_NOTICE)は除去してから、必要時のみ再付与する。
// =====================================================================

module.exports = async (params) => {
  const { app } = params;

  // QuickAdd API を「params から」or「プラグイン本体から」取得
  // （Macro 実行時は params 経由、そうでない場合はプラグイン本体から取得を試みる）
  const qa =
    params?.quickAddApi ??
    app?.plugins?.plugins?.quickadd?.api ??
    app?.plugins?.plugins?.["quickadd"]?.api;

  // suggester が使えない＝QuickAdd から正しく呼ばれていない可能性が高いので中断
  if (!qa?.suggester) {
    new Notice("QuickAdd API が取得できません。QuickAdd の Macro から実行しているか確認してください。");
    return;
  }

  // =========================================================
  // 設定（ユーザー/フォルダが増えたら USER_TARGETS に追記する）
  // =========================================================
  const USER_TARGETS = [
    { key: "masa", label: "masa", folder: "50_masaタスク管理" },
    { key: "tomo", label: "tomo", folder: "51_tomoタスク管理" },
  ];

  // 履歴保管フォルダ（Vault直下・全ユーザー共通）
  const ARCHIVE_FOLDER = "999_履歴保管(古いファイル)";

  // ファイル名のプレフィックス
  const PLAN_PREFIX = "【予定】";       // 予定ファイルの接頭辞
  const RUN_PREFIX_RE = /^【実行中】\s*/; // 実行中ファイルの接頭辞判定

  // 日付キーは "YYYYMMDD(曜)" 形式（例: 20260714(火)）
  const KEY_RE = /^(\d{8})\(([日月火水木金土])\)$/;
  // 【予定】YYYYMMDD(曜).md を丸ごと判定する正規表現
  const PLAN_PREFIX_RE = new RegExp(`^${PLAN_PREFIX}(\\d{8}\\([日月火水木金土]\\))\\.md$`);

  // 予定を取り込んだときに本文先頭へ入れる案内文
  const PLAN_NOTICE = "**※予定タスクを一番下に追加しました。**";
  // 予定ファイル2件目以降で重複除去する対象ヘッダー行
  const PLAN_DEDUP_HEADER = "> [!danger] 🔴🔴🔴🔴🔴 予定タスク(追加) 🔴🔴🔴🔴🔴";

  // --- 小さなユーティリティ ---
  const pad2 = (n) => String(n).padStart(2, "0");        // 数値を2桁ゼロ埋め
  const weekdayJP = (d) => "日月火水木金土"[d.getDay()]; // Date から日本語曜日1文字
  const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // 正規表現メタ文字のエスケープ

  // "YYYYMMDD(曜)" → Date（形式が違えば null）
  const keyToDate = (key) => {
    const m = key.match(/^(\d{4})(\d{2})(\d{2})\(([日月火水木金土])\)$/);
    if (!m) return null;
    const y = Number(m[1]);
    const mo = Number(m[2]) - 1;
    const d = Number(m[3]);
    return new Date(y, mo, d);
  };

  // Date → "YYYYMMDD(曜)"
  const dateToKey = (dt) => {
    return `${dt.getFullYear()}${pad2(dt.getMonth() + 1)}${pad2(dt.getDate())}(${weekdayJP(dt)})`;
  };

  // "YYYYMMDD(曜)" → 翌日の "YYYYMMDD(曜)"（新規ファイルの日付計算に使用）
  const addOneDayKey = (key) => {
    const dt = keyToDate(key);
    if (!dt) return null;
    dt.setDate(dt.getDate() + 1);
    return dateToKey(dt);
  };

  // "【予定】YYYYMMDD(曜).md" から日付キー部分を取り出す（該当しなければ null）
  const planNameToKey = (fileName) => {
    const m = fileName.match(PLAN_PREFIX_RE);
    return m?.[1] ?? null;
  };

  // 時刻を切り捨てて「その日の0時」のミリ秒を返す（日付だけの比較用）
  const dateOnlyTime = (dt) => new Date(dt.getFullYear(), dt.getMonth(), dt.getDate()).getTime();

  // 日付キーが [startDate, endDate]（両端含む・日付単位）の範囲内かどうか
  const isKeyInDateRange = (key, startDate, endDate) => {
    const dt = keyToDate(key);
    if (!dt) return false;
    const time = dateOnlyTime(dt);
    return dateOnlyTime(startDate) <= time && time <= dateOnlyTime(endDate);
  };

  // "【実行中】YYYYMMDD(曜).md" から日付キーを取り出す（形式外なら null）
  const runningNameToKey = (fileName) => {
    const stripped = fileName.replace(RUN_PREFIX_RE, "").replace(/\.md$/i, "");
    return KEY_RE.test(stripped) ? stripped : null;
  };

  // 履歴フォルダへ移動する際に、同名ファイルがあれば " (1)" のように連番を付けて衝突回避
  const ensureUniquePath = (folder, fileName) => {
    const lower = fileName.toLowerCase();
    const hasMd = lower.endsWith(".md");
    const stem = hasMd ? fileName.slice(0, -3) : fileName;
    const ext = hasMd ? ".md" : "";

    // まず素のファイル名で空きがあればそれを使う
    let candidate = `${folder}/${fileName}`;
    if (!app.vault.getAbstractFileByPath(candidate)) return candidate;

    // 空きが無ければ連番を付けて探す
    for (let i = 1; i < 1000; i++) {
      candidate = `${folder}/${stem} (${i})${ext}`;
      if (!app.vault.getAbstractFileByPath(candidate)) return candidate;
    }
    // 1000件まで埋まっている異常時のフォールバック（タイムスタンプで一意化）
    return `${folder}/${stem} (${Date.now()})${ext}`;
  };

  // =========================================================
  // ★修正1：履歴フォルダの用意を安全化する共通関数
  //   - フォルダが既に存在すればそのまま true
  //   - 同名の「ファイル」が存在する場合は作成できないため検知して中断(false)
  //   - 不存在なら作成し、作成失敗は捕捉して Notice 表示 → false
  //   戻り値: 利用可能なら true / 失敗なら false（呼び出し側で退避をスキップする）
  // =========================================================
  const ensureArchiveFolder = async () => {
    const existing = app.vault.getAbstractFileByPath(ARCHIVE_FOLDER);

    if (existing) {
      // 同名だが「フォルダではない（＝ファイル）」場合は危険なので中断
      const isFolder = !!existing.children || existing instanceof Object && "children" in existing;
      if (!isFolder && !existing.children) {
        // TFolder は children を持つ。ファイル(TFile)には children が無い。
        if (existing.children === undefined) {
          new Notice(`履歴保管フォルダと同名のファイルが存在するため退避できません：${ARCHIVE_FOLDER}`);
          return false;
        }
      }
      return true;
    }

    // 不存在なら作成（失敗は捕捉）
    try {
      await app.vault.createFolder(ARCHIVE_FOLDER);
      return true;
    } catch (e) {
      new Notice(`履歴保管フォルダの作成に失敗したため退避できません：${e?.message ?? e}`);
      return false;
    }
  };

  // =========================================================
  // ★修正2：本文先頭に残っている既存の予定案内文(PLAN_NOTICE)を除去する
  //   前日の【実行中】に付いた案内文をそのまま連結すると累積するため、
  //   本文採用前に先頭付近の案内文を取り除く。
  //   （案内文行と、その直後に続く空行をまとめて除去する）
  // =========================================================
  const removeExistingPlanNotice = (text) => {
    if (!text) return text;
    const noticeRe = new RegExp(`^\\s*${escapeRegExp(PLAN_NOTICE)}\\s*(?:\\n+)?`, "g");
    return text.replace(noticeRe, "");
  };

  // =========================================================
  // 1) ユーザー選択（suggester で対象フォルダを決める）
  // =========================================================
  const labels = USER_TARGETS.map((x) => x.label);
  const pickedLabel = await qa.suggester(labels, labels, "ユーザーを選択してください");
  if (!pickedLabel) {
    new Notice("キャンセルしました。");
    return;
  }

  const picked = USER_TARGETS.find((x) => x.label === pickedLabel);
  if (!picked) {
    new Notice("選択が不正です。");
    return;
  }

  const targetFolder = picked.folder; // このユーザーのタスク管理フォルダ

  // =========================================================
  // 2) 対象フォルダ配下の .md のみを走査対象にする
  // =========================================================
  const allMdFiles = app.vault.getFiles().filter((f) => f.extension === "md");
  const scopePrefix = `${targetFolder}/`;
  const scopedFiles = allMdFiles.filter((f) => f.path.startsWith(scopePrefix));

  // 対象フォルダ内の【実行中】ファイルを収集（パス順に整列）
  const runningFiles = scopedFiles
    .filter((f) => RUN_PREFIX_RE.test(f.name))
    .sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));

  // =========================================================
  // 日付形式外の【実行中】ファイル検出
  //   runningFiles に日付形式(YYYYMMDD(曜))でないものがあると、
  //   本文コピー・履歴退避のどちらからも漏れて放置されてしまう。
  //   そのため見つかった時点で処理を停止し、ユーザーへ通知する。
  // =========================================================
  const invalidRunningFiles = runningFiles.filter((f) => !runningNameToKey(f.name));
  if (invalidRunningFiles.length > 0) {
    const names = invalidRunningFiles.map((f) => f.name).join("、");
    new Notice(`日付形式ではない【実行中】ファイルが存在します：${names}`);
    return;
  }

  // =========================================================
  // 3) 新規【実行中】の日付を決める =（既存実行中の最新）+1日
  //    ・sourceRunningFile … 本文の元にもし、履歴退避もする「最新1件」
  //    ・otherRunningFiles … 本文には使わないが履歴退避すべき「残りの旧実行中」
  // =========================================================
  let newKey = null;    // 新規ファイルの日付キー
  let latestKey = null; // 既存実行中の最新日付キー

  // ★コピー元（本文生成にも履歴退避にも使う「最新1件」）
  /** @type {import('obsidian').TFile|null} */
  let sourceRunningFile = null;

  // ★本文生成には使わないが履歴退避すべき「残りの旧【実行中】」
  /** @type {import('obsidian').TFile[]} */
  let otherRunningFiles = [];

  if (runningFiles.length > 0) {
    // ファイルと日付キーの対応表を作る（キーが読めるものだけ残す）
    const entries = runningFiles
      .map((f) => ({ file: f, key: runningNameToKey(f.name) }))
      .filter((x) => !!x.key);

    // 上の invalid チェックを通っていれば通常ここには来ないが、念のための保険
    if (entries.length === 0) {
      new Notice("既存【実行中】はあるが日付形式が読めません。ファイル名形式を確認してください。");
      return;
    }

    // 日付(YYYYMMDD)の昇順に並べ、末尾＝最新を採用
    entries.sort((a, b) => Number(a.key.slice(0, 8)) - Number(b.key.slice(0, 8)));
    const latest = entries[entries.length - 1];
    latestKey = latest.key;
    sourceRunningFile = latest.file;

    // ★最新1件を除いた残りの旧【実行中】（本文には使わず履歴退避のみ対象）
    otherRunningFiles = entries
      .filter((x) => x.file.path !== sourceRunningFile.path)
      .map((x) => x.file);

    // 新規ファイルは「最新＋1日」の日付にする
    const computed = addOneDayKey(latestKey);
    if (!computed) {
      new Notice("新規日付キーの計算に失敗しました。");
      return;
    }
    newKey = computed;
  } else {
    // 既存の実行中が1件も無ければ、本日日付で新規作成する
    newKey = dateToKey(new Date());
  }

  // =========================================================
  // 新規作成日が「本日」でない場合の確認
  //   （数日ぶんスキップして複製しようとしていないか、ユーザーに確認する）
  // =========================================================
  const todayKey = dateToKey(new Date());
  const todayYmd = todayKey.slice(0, 8);
  const newYmd = newKey.slice(0, 8);

  if (newYmd !== todayYmd) {
    // 複製元キーと本日の差分日数を計算して案内文に含める
    const srcKey = latestKey ?? newKey;
    const srcDate = keyToDate(srcKey);
    const nowDate = keyToDate(todayKey);

    let gapDays = null;
    if (srcDate && nowDate) {
      gapDays = Math.floor((nowDate.getTime() - srcDate.getTime()) / (24 * 60 * 60 * 1000));
    }

    const daysText = gapDays !== null ? `${gapDays}` : "数";
    const msg =
      `複製元の日付が『${srcKey}』で${daysText}日間複製されていません。本日の日付で新規ファイルを複製しますか？`;

    // OK なら新規日付を本日に補正、キャンセルなら「最新＋1日」のまま
    const ok = window.confirm(msg);
    if (ok) {
      newKey = todayKey;
    }
  }

  // 新規ファイル名・パスを確定
  const baseName = `${newKey}.md`;
  const runningName = `【実行中】${baseName}`;
  const planTargetKey = newKey;

  const targetBasePath = `${targetFolder}/${baseName}`;
  const targetRunningPath = `${targetFolder}/${runningName}`;

  // 同名ファイルがすでに存在する場合は上書き事故を避けるため中断
  if (app.vault.getAbstractFileByPath(targetBasePath)) {
    new Notice(`同名ファイルが存在します（通常ファイル）：${targetBasePath}`);
    return;
  }
  if (app.vault.getAbstractFileByPath(targetRunningPath)) {
    new Notice(`同名ファイルが存在します（【実行中】ファイル）：${targetRunningPath}`);
    return;
  }

  // =========================================================
  // 4) 【予定】ファイルの収集（実行中が存在する場合のみ・過去30日）
  //    新規日付を終端として、そこから29日前までを取り込み対象にする。
  // =========================================================
  const planTargetDate = keyToDate(planTargetKey);
  const planStartDate = planTargetDate ? new Date(planTargetDate) : null;
  if (planStartDate) planStartDate.setDate(planStartDate.getDate() - 29);

  const plannedFiles =
    runningFiles.length === 0 || !planTargetDate || !planStartDate
      ? [] // 実行中が無い or 日付計算失敗時は予定を取り込まない
      : scopedFiles
          .map((file) => ({ file, key: planNameToKey(file.name) }))
          .filter((x) => x.key && isKeyInDateRange(x.key, planStartDate, planTargetDate))
          .sort((a, b) => {
            // 日付昇順、同日ならパス順で安定ソート
            const byDate = Number(a.key.slice(0, 8)) - Number(b.key.slice(0, 8));
            if (byDate !== 0) return byDate;
            return a.file.path < b.file.path ? -1 : a.file.path > b.file.path ? 1 : 0;
          })
          .map((x) => x.file);

  // =========================================================
  // 5) 本文の組み立て（実行中の最新1件 → 予定を末尾に追記）
  //    ・実行中の本文は「最新1件(sourceRunningFile)」のみを採用（全件連結はしない）
  //    ・本文採用前に既存の予定案内文(PLAN_NOTICE)を除去して累積を防ぐ
  //    ・予定は連結し、2件目以降は重複ヘッダーだけ除去
  //    ・予定を取り込んだ場合のみ、本文先頭に案内文を付ける
  //    読み込み失敗時は例外を伝播させ、作成・退避を行わず安全に中断する。
  // =========================================================

  // ファイルを読み、改行コード統一＋末尾改行の除去を行う。
  // 失敗時は例外をそのまま投げる（呼び出し側 try/catch で捕捉して中断）。
  const readAndNormalize = async (file) => {
    const text = await app.vault.read(file);
    return (text ?? "").replace(/\r\n/g, "\n").replace(/\n+$/g, "");
  };

  // 予定ファイル本文から、重複する予定ヘッダー行を取り除く
  const removeDuplicatePlanHeader = (text) => {
    const headerRe = new RegExp(`${escapeRegExp(PLAN_DEDUP_HEADER)}(?:[ \\t]*\\n)*`, "g");
    return text.replace(headerRe, "");
  };

  let copiedContent = "";      // 新規ファイルへ書き込む本文
  let didAppendPlanned = false; // 予定を実際に追記したかどうか

  if (runningFiles.length > 0) {
    try {
      // ★実行中の本文は「最新1件」のみを採用（全件連結を廃止＝重複対策の要）
      //   ＋ 前日ファイルに残る予定案内文を除去してから採用（累積防止）
      const rawBase = sourceRunningFile ? await readAndNormalize(sourceRunningFile) : "";
      const base = removeExistingPlanNotice(rawBase).trim();

      // 予定ファイルを順に読み、1件目はそのまま、2件目以降はヘッダー重複を除去
      const planContents = [];
      for (let i = 0; i < plannedFiles.length; i++) {
        const text = await readAndNormalize(plannedFiles[i]);
        planContents.push(i === 0 ? text : removeDuplicatePlanHeader(text));
      }
      const appended = planContents.join("\n\n").trim();

      didAppendPlanned = plannedFiles.length > 0 && !!appended;

      // 本文（実行中）＋予定を連結。どちらか片方だけならそれを採用
      if (base && appended) copiedContent = `${base}\n\n${appended}`;
      else copiedContent = base || appended || "";
    } catch (e) {
      // 読み込み失敗＝内容欠落のまま作成/退避すると危険なので中断
      new Notice(
        `ファイル読み込みに失敗したため処理を中断しました（ファイルは作成・退避していません）：${e?.message ?? e}`
      );
      return;
    }
  }

  // 予定を追記した場合のみ、本文先頭に案内文を付与（除去済みなので累積しない）
  if (didAppendPlanned) {
    if (copiedContent.trim()) copiedContent = `${PLAN_NOTICE}\n\n${copiedContent.trim()}\n`;
    else copiedContent = `${PLAN_NOTICE}\n`;
  }

  // =========================================================
  // 6) 新規【実行中】ファイルの作成 ＋ アクティブ化
  //    先に作成を成功させてから、後続の退避処理へ進む
  //    （作成に失敗した場合は退避を行わず中断する）
  // =========================================================
  if (!app.vault.getAbstractFileByPath(targetFolder)) {
    await app.vault.createFolder(targetFolder);
  }

  let createdFile = null;
  try {
    createdFile = await app.vault.create(targetRunningPath, copiedContent);
  } catch (e) {
    new Notice(`新規ファイルの作成に失敗したため処理を中断しました：${e?.message ?? e}`);
    return;
  }

  // 作成したファイルをエディタで開いてアクティブにする（失敗しても致命的ではない）
  try {
    const leaf = app.workspace.getLeaf(false);
    await leaf.openFile(createdFile, { active: true });
    app.workspace.setActiveLeaf(leaf, { focus: true });
  } catch {
    new Notice("ファイルは作成しましたが、アクティブ化に失敗しました。");
  }

  // 履歴退避中に発生した移動失敗を集約する（最後の通知で警告表示に使う）
  const moveErrors = [];

  // =========================================================
  // 7) 【予定】ファイルを履歴保管へ退避（新規作成成功後）
  //    ★修正1：ensureArchiveFolder() で履歴フォルダを安全に用意する
  // =========================================================
  if (runningFiles.length > 0 && plannedFiles.length > 0) {
    const archiveReady = await ensureArchiveFolder();
    if (!archiveReady) {
      moveErrors.push("履歴保管フォルダを用意できず、予定ファイルを退避できませんでした。");
    } else {
      for (const f of plannedFiles) {
        // 履歴側では「ユーザーlabel_元ファイル名」にして、誰の分か分かるようにする
        const destName = `${picked.label}_${f.name}`;
        const destPath = ensureUniquePath(ARCHIVE_FOLDER, destName);
        try {
          await app.vault.rename(f, destPath);
        } catch {
          moveErrors.push(`予定ファイル移動に失敗: ${f.path}`);
        }
      }
    }
  }

  // =========================================================
  // 8) 旧【実行中】ファイルを履歴へ退避
  //    ・最新1件(sourceRunningFile)：本文の元になったファイル
  //    ・残りの旧実行中(otherRunningFiles)：本文には使っていないファイル
  //    両方をまとめて退避することで「読む集合」と「退避する集合」を一致させ、
  //    旧ファイル残置による次回の再連結（累積重複）を防ぐ。
  //    ★修正1：ensureArchiveFolder() で履歴フォルダを安全に用意する
  // =========================================================
  const runningToArchive = [];
  if (sourceRunningFile) runningToArchive.push(sourceRunningFile);
  for (const f of otherRunningFiles) runningToArchive.push(f);

  if (runningToArchive.length > 0) {
    const archiveReady = await ensureArchiveFolder();
    if (!archiveReady) {
      moveErrors.push("履歴保管フォルダを用意できず、旧【実行中】ファイルを退避できませんでした。");
    } else {
      for (const f of runningToArchive) {
        // 念のため、今作成した新規ファイル自身は退避対象から除外する
        if (createdFile && f.path === createdFile.path) continue;

        const destName = `${picked.label}_${f.name}`;
        const destPath = ensureUniquePath(ARCHIVE_FOLDER, destName);

        try {
          await app.vault.rename(f, destPath);
        } catch {
          moveErrors.push(`旧【実行中】の履歴移動に失敗: ${f.path}`);
        }
      }
    }
  }

  // =========================================================
  // 9) 完了通知
  //    移動失敗が1件でもあれば、成功扱いにせず警告付きで内容を知らせる。
  // =========================================================
  if (moveErrors.length > 0) {
    new Notice(
      `⚠️ 作成しましたが一部の移動に失敗しました: ${targetRunningPath}\n` +
        moveErrors.join("\n")
    );
  } else {
    new Notice(`作成しました: ${targetRunningPath}`);
  }
};
