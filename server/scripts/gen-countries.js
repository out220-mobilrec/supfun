/// One-off generator: builds a compact countries reference (ISO 3166-1 alpha-2 + Russian name)
/// from the mledoze/countries dataset. Run: node scripts/gen-countries.js <src.json>
/// Source: https://github.com/mledoze/countries (ODbL / CC-BY-SA).
const fs = require('fs');
const path = require('path');

const src = process.argv[2] || path.join(__dirname, '.countries-src.json');
const out = path.join(__dirname, '..', 'src', 'modules', 'reference', 'data', 'countries.data.ts');

const raw = JSON.parse(fs.readFileSync(src, 'utf8'));

const rows = raw
  .filter((c) => c.cca2 && !c.disabled)
  .map((c) => ({
    code: c.cca2,
    name: (c.translations && c.translations.rus && (c.translations.rus.common || c.translations.rus.official))
      || c.name.common,
    nameEn: c.name.common,
  }))
  .filter((c) => c.code.length === 2)
  .sort((a, b) => a.name.localeCompare(b.name, 'ru'));

// De-duplicate by code just in case
const byCode = new Map(rows.map((r) => [r.code, r]));
const list = [...byCode.values()];

fs.mkdirSync(path.dirname(out), { recursive: true });
// TS-модуль, а не JSON: сборка сервера — это `tsc -p tsconfig.build.json`
// без copy-assets, JSON в dist не попал бы.
const body = list
  .map((c) => `  { code: '${c.code}', name: '${c.name.replace(/'/g, "\'")}', nameEn: '${c.nameEn.replace(/'/g, "\'")}' },`)
  .join('\n');
fs.writeFileSync(
  out,
  `// Справочник стран: ISO 3166-1 alpha-2 + название (RU/EN).\n` +
    `// Сгенерировано scripts/gen-countries.js из датасета mledoze/countries — не редактировать вручную.\n` +
    `export interface CountryRow {\n  code: string;\n  name: string;\n  nameEn: string;\n}\n\n` +
    `export const COUNTRIES: CountryRow[] = [\n${body}\n];\n`,
  'utf8',
);
console.log(`wrote ${list.length} countries -> ${path.relative(process.cwd(), out)}`);
console.log('RU present:', list.some((c) => c.code === 'RU'));
