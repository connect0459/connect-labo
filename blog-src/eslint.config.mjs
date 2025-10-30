// @ts-check
import eslintPluginAstro from "eslint-plugin-astro";
import tseslint from "typescript-eslint";

export default [
  // TypeScriptファイル用の設定
  ...tseslint.configs.recommended,

  // Astroファイル用の設定
  ...eslintPluginAstro.configs.recommended,

  {
    rules: {
      // プロジェクトに合わせてカスタマイズ可能
    },
  },

  {
    ignores: ["dist/**", ".astro/**", "node_modules/**"],
  },
];
