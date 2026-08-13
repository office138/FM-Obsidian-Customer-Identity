// collapse-file-explorer-folders.js
// QuickAdd User Script 用
// 目的：左サイドバーは残したまま、File Explorer 内の
//       トップフォルダ配下のサブフォルダも含めて全て折りたたむ

module.exports = async () => {
  const getExplorerRoots = () => {
    return Array.from(
      document.querySelectorAll(".workspace-leaf-content[data-type='file-explorer']")
    );
  };

  const clickToggle = (folderEl) => {
    if (!folderEl) return false;

    const toggle =
      folderEl.querySelector(":scope > .tree-item-self .collapse-icon") ||
      folderEl.querySelector(":scope > .tree-item-self .tree-item-icon") ||
      folderEl.querySelector(":scope > .tree-item-self");

    if (!toggle) return false;

    try {
      toggle.click();
      return true;
    } catch (_) {
      try {
        toggle.dispatchEvent(
          new MouseEvent("click", {
            bubbles: true,
            cancelable: true,
            view: window,
          })
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  };

  const collapseAllFoldersDeep = (root) => {
    let changedAny = false;
    const MAX_PASSES = 100;

    for (let pass = 0; pass < MAX_PASSES; pass++) {
      const expandedFolders = Array.from(
        root.querySelectorAll(".tree-item.nav-folder:not(.is-collapsed)")
      );

      if (expandedFolders.length === 0) break;

      let changedThisPass = 0;

      // 深い階層から順に折りたたむため逆順
      for (let i = expandedFolders.length - 1; i >= 0; i--) {
        const folder = expandedFolders[i];
        if (clickToggle(folder)) {
          changedThisPass++;
          changedAny = true;
        }
      }

      if (changedThisPass === 0) break;
    }

    return changedAny;
  };

  const roots = getExplorerRoots();
  if (!roots.length) return;

  for (const root of roots) {
    try {
      collapseAllFoldersDeep(root);
    } catch (_) {
      // 個別ペインの失敗は無視
    }
  }
};