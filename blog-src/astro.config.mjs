// @ts-check

import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

// 開発環境では base を設定しない
const isDev = process.env.NODE_ENV !== "production";

// https://astro.build/config
export default defineConfig({
  site: isDev ? undefined : "https://connect0459.github.io",
  // GitHub Pagesのプロジェクトサイト用のベースパス（本番環境のみ）
  base: isDev ? undefined : "/connect-labo",
  integrations: [mdx(), sitemap()],
  vite: {
    plugins: [tailwindcss()],
  },
});
