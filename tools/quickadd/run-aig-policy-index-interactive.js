/**
* ============================
* A方式：QuickAdd(JS) → CMDラッパー → PowerShell(ps1) 実行（対話あり）
* 固定パスなし（VaultRoot自動取得）
* 最終フォルダ構成は下記の通り。
* 【Vault】INS
* └─ scripts
*    ├─ Update-Obsidian-aigPolicyIndex.ps1      # 本体（対話あり）
*    ├─ run_aigPolicyIndex_interactive.cmd      # CMDラッパー
*    └─ quickadd    # QuickAdd専用のスクリプトフォルダ
*              └─ run-aig-policy-index-interactive.js     # QuickAddランチャー（←確定）
*  ============================
* 
*  2) QuickAdd：JavaScript（scripts\run-aig-policy-index-interactive.js）
*     - VaultRootを自動取得（固定パス不要）
*     - scripts\run_aigPolicyIndex_interactive.cmd を起動
*     - Windows環境（PowerShell/CMD）前提
*  ------------------------------------------------------------
*/
module.exports = async () => {
  const path = require("path");
  const fs = require("fs");
  const { shell } = require("electron"); // ObsidianはElectronアプリ

  const vaultRoot = app.vault.adapter.getBasePath();
  const cmdPath = path.join(vaultRoot, "scripts", "run_aigPolicyIndex_interactive.cmd");

  if (!fs.existsSync(cmdPath)) {
    new Notice("❌ CMDが見つかりません: " + cmdPath);
    throw new Error("CMD not found: " + cmdPath);
  }

  // Windows Shell に「このファイルを開け」と委ねる（= .cmd は実行される）
  const result = await shell.openPath(cmdPath);

  if (result) {
    // result が空文字以外ならエラーメッセージが返る
    new Notice("❌ 起動失敗: " + result);
    throw new Error(result);
  }

  new Notice("▶ AIG契約一覧スクリプトを起動しました（PowerShell画面で操作してください）");
};