# GitHub連携・環境設定 備忘録

- **設定日時**: 2026年8月12日
- **対象ローカルフォルダ**: `D:\FM-Script-Backup`
- **正（マスター）リポジトリ**: `https://github.com/office138/FM-Obsidian-Customer-Identity`
- **対象ブランチ**: `main`

---

## 1. 連携構成の概要

本フォルダ（`D:\FM-Script-Backup`）は、GitHub上の `office138/FM-Obsidian-Customer-Identity` リポジトリを「正」としてGit管理下に置かれています。

| 項目 | 設定値 |
| :--- | :--- |
| **Gitユーザー名** | `office138` |
| **Gitメールアドレス** | `is.ichinomiyam@gmail.com` |
| **リモートURL (origin)** | `https://github.com/office138/FM-Obsidian-Customer-Identity.git` |
| **アップストリーム** | `origin/main` に追跡設定済み |

---

## 2. GitHubへの書き込み（Push）準備

現在、GitHubからの最新コード取得（Pull / Fetch）は設定済みです。
今後、ローカルで変更を行った内容をGitHubへ書き込む（`git push`）場合は、以下のSSHキーをGitHubへ登録してください。

### ローカルPCのSSH公開鍵 (`~/.ssh/id_ed25519.pub`)
```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHeqDkcoj8892ZTugXXp7wuCEAEKHA1s37uq3wuFnCas teraterm-new-pc
```

### 登録手順
1. [GitHub SSH Key 設定ページ](https://github.com/settings/keys) へアクセス。
2. **New SSH key** をクリック。
3. **Title** に `PC-ED25519` 等を入力し、**Key** の欄に上記の公開鍵文字列を貼り付けて保存。
4. SSH登録後、以下のコマンドでリモートURLをSSH形式に変更します：
   ```powershell
   git remote set-url origin git@github.com:office138/FM-Obsidian-Customer-Identity.git
   ```

---

## 3. 日常よく使うGit操作コマンド

### 最新状態の取得 (GitHub → ローカル)
```powershell
git pull origin main
```

### ステータス確認
```powershell
git status
```

### 変更履歴の確認
```powershell
git log --oneline -n 10
```

### ローカルの変更をGitHubへ送る場合 (Push権限設定後)
```powershell
git add .
git commit -m "変更内容のメモ"
git push origin main
```

---

## 4. ローカルバックアップフォルダの扱い

`D:\FM-Script-Backup` 直下の以下のフォルダ群は、元々存在していたバックアップデータとして保持されています：
- `Antigravity/`, `ChatGPT/`, `Claude/`, `Diagnostics/`, `Filemaker-script/`, `GitHub-Staging/`, `Snapshot/` 等

これらは現在 Git の追跡対象外（Untracked）として残されていますので、必要に応じて保存・整理を行ってください。
