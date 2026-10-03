export const quantity = (n = 0, digits = 1) =>
  (n / 1000).toLocaleString('en-US', { maximumFractionDigits: digits });
export const percent = (n = 0) => `${Math.round(n / 100)}%`;
export const goodArt = ['good-berries', 'good-meat', 'good-wood', 'good-stone', 'good-spear'];
export const roleColors = ['#80928b', '#7fc363', '#d69556', '#5dafa6', '#79a7d5', '#a888d0'];
export const art = (name: string) => `/art/${name}.png`;
