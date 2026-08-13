module.exports = () => {
  // Obsidian標準の機能(moment)を使って時間を取得
  const time = window.moment().format("HH:mm");
  
  // ここで返した文字が、ノートの <% ... %> の部分に置き換わります
  return ` ※開始:${time}`;
};