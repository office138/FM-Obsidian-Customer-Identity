module.exports = async () => {
  const path = require("path");
  const fs = require("fs");
  const { shell } = require("electron");

  const vaultRoot = app.vault.adapter.getBasePath();
  const cmdPath = path.join(vaultRoot, "scripts", "run_aigJikoIndex_interactive.cmd");

  if (!fs.existsSync(cmdPath)) {
    new Notice("❌ CMDが見つかりません: " + cmdPath);
    throw new Error("CMD not found: " + cmdPath);
  }

  const result = await shell.openPath(cmdPath);

  if (result) {
    new Notice("❌ 起動失敗: " + result);
    throw new Error(result);
  }

  new Notice("▶ AIG事故一覧スクリプトを起動しました");
};