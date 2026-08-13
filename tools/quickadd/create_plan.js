/**
 * 作成日: 2026-04-01
 * 機能: 現在アクティブなフォルダ内に、ユーザーが入力した日付（YYYYMMDD）に基づいた予定管理用ファイルを作成する。
 * ファイル名は「【予定】YYYYMMDD(曜日)」とし、既に同名ファイルがある場合は上書きせずに終了する。
 * 作成後、自動的にそのファイルを新しいタブで開く。
 */
module.exports = async (params) => {
    const { app, quickAddApi } = params;
    const { Notice } = require("obsidian");

    // 1. 現在アクティブなフォルダを取得
    // アクティブなファイルがない場合はルート（一番上の階層）になります
    const activeFile = app.workspace.getActiveFile();
    let folderPath = "";
    
    if (activeFile && activeFile.parent) {
        folderPath = activeFile.parent.path;
    }

    // 2. ユーザーに日付を入力させる
    const inputDateStr = await quickAddApi.inputPrompt(
        "予定日を入力してください (8桁の数字)",
        "例: 20260401"
    );

    // キャンセルされた場合
    if (!inputDateStr) {
        new Notice("処理をキャンセルしました。");
        return;
    }

    // 3. 入力値の形式チェック (YYYYMMDDの8桁か)
    if (!/^\d{8}$/.test(inputDateStr)) {
        new Notice("エラー: YYYYMMDD形式の8桁の数字で入力してください。");
        return;
    }

    // 年・月・日を抽出して数値化
    const year = parseInt(inputDateStr.substring(0, 4), 10);
    const month = parseInt(inputDateStr.substring(4, 6), 10);
    const day = parseInt(inputDateStr.substring(6, 8), 10);

    // 存在しない日付をチェック
    const dateObj = new Date(year, month - 1, day);
    if (dateObj.getFullYear() !== year || dateObj.getMonth() !== month - 1 || dateObj.getDate() !== day) {
        new Notice("エラー: 存在しない日付です。");
        return;
    }

    // 4. 曜日を計算してファイル名を生成
    const days = ["日", "月", "火", "水", "木", "金", "土"];
    const dayOfWeekStr = days[dateObj.getDay()];
    const fileName = `【予定】${inputDateStr}(${dayOfWeekStr})`;

    // 保存先パスの決定（ルート階層の場合はスラッシュを入れない調整）
    const fullPath = (folderPath === "" || folderPath === "/") 
        ? `${fileName}.md` 
        : `${folderPath}/${fileName}.md`;

    // 5. 重複チェック
    const fileExists = app.vault.getAbstractFileByPath(fullPath);
    if (fileExists) {
        new Notice(`中止: 「${fileName}」は既に存在するため、作成をスキップしました。`);
        return;
    }

    // 6. ファイルの内容を定義
    const content = `> [!danger] 🔴🔴🔴🔴🔴 予定タスク(追加) 🔴🔴🔴🔴🔴\n- [ ] `;

    // 7. ファイルの作成とオープン
    try {
        const newFile = await app.vault.create(fullPath, content);
        
        // 作成したファイルを新しいタブで開く
        await app.workspace.getLeaf(false).openFile(newFile);
        
        new Notice(`「${folderPath}」に予定ファイルを作成しました。`);

    } catch (error) {
        console.error("ファイル作成エラー:", error);
        new Notice("エラー: ファイルの作成に失敗しました。");
    }
};