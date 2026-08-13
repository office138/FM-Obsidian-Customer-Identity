// QuickAdd User Script
// 仕様：
// ・frontmatter の「始期」の “年だけ” を +1 して「終期」へ格納（MM/DD はそのまま）
// ・「始期」が空欄/未設定なら Notice を出して何もしない
// ・日付形式は YYYY/MM/DD, YYYY-MM-DD, YYYY/M/D を許容

module.exports = async (params) => {
  const { app, obsidian } = params;
  const Notice = obsidian.Notice;

  const START_KEY = "始期";
  const END_KEY = "終期";

  const file = app.workspace.getActiveFile();
  if (!file) {
    new Notice("アクティブなノートがありません");
    return;
  }

  // frontmatter 参照
  const cache = app.metadataCache.getFileCache(file);
  const fm = cache?.frontmatter;

  const startRaw = fm?.[START_KEY];
  if (!startRaw) {
    new Notice("「始期」を入力してから再実行してください！");
    return;
  }

  // 厳密パース
  const m = window.moment(
    String(startRaw).trim(),
    ["YYYY/MM/DD", "YYYY-MM-DD", "YYYY/M/D", "YYYY-M-D"],
    true
  );

  if (!m.isValid()) {
    new Notice("「始期」の日付形式が正しくありません（例：2025/12/29）");
    return;
  }

  // 年のみ +1（= 月日コピー）
  const end = m.clone().add(1, "year").format("YYYY/MM/DD");

  // frontmatter 更新
  await app.fileManager.processFrontMatter(file, (frontmatter) => {
    frontmatter[END_KEY] = end;
  });

  new Notice(`終期を ${end} に設定しました`);
};
