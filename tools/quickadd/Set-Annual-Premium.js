// Set-Annual-Premium.js
// QuickAdd User Script: 月保険料を入力 → 年保険料(月*12)をFrontmatterへ自動入力

module.exports = async (params) => {
  const { app, quickAddApi } = params;

  const file = app.workspace.getActiveFile();
  if (!file) {
    new Notice("アクティブなノートが見つかりません。");
    return;
  }

  // 入力値を数値に変換（カンマや￥などを除去）
  const toNumber = (v) => {
    if (v === null || v === undefined) return null;
    const s = String(v).replace(/[^\d.-]/g, ""); // 例: "26,870円" → "26870"
    if (s.trim() === "") return null;
    const n = Number(s);
    return Number.isFinite(n) ? n : null;
  };

  // 既存FMの月保険料を読み、なければ入力を促す
  const cache = app.metadataCache.getFileCache(file);
  const fm = cache?.frontmatter ?? {};
  let monthly = toNumber(fm["月保険料"]);

  if (monthly === null) {
    const input = await quickAddApi.inputPrompt(
      "月保険料を入力してください（例: 26870 / 26,870 / 26870円）",
      ""
    );
    monthly = toNumber(input);
  }

  if (monthly === null) {
    new Notice("月保険料が数値として認識できませんでした。");
    return;
  }

  const annual = monthly * 12;

  await app.fileManager.processFrontMatter(file, (frontmatter) => {
    frontmatter["月保険料"] = monthly;
    frontmatter["年保険料"] = annual;
  });

  new Notice(`更新しました：月保険料=${monthly} / 年保険料=${annual}`);
};
