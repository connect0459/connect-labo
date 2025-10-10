import { defineCollection, z } from 'astro:content';
import { glob, file } from 'astro/loaders';

// 単一記事（Zenn風のarticles）
const articles = defineCollection({
	loader: glob({ base: './src/content/articles', pattern: '**/*.{md,mdx}' }),
	schema: ({ image }) =>
		z.object({
			title: z.string(),
			emoji: z.string().optional(), // Zenn風の絵文字
			type: z.enum(['tech', 'idea']).default('tech'), // 記事タイプ
			topics: z.array(z.string()).default([]), // タグ
			published: z.boolean().default(true),
			pubDate: z.coerce.date(),
			updatedDate: z.coerce.date().optional(),
		}),
});

// 本形式（Zenn風のbooks）
const books = defineCollection({
	loader: glob({ base: './src/content/books', pattern: '**/config.yml' }),
	schema: ({ image }) =>
		z.object({
			title: z.string(),
			summary: z.string(),
			topics: z.array(z.string()).default([]),
			published: z.boolean().default(true),
			price: z.number().default(0), // 無料=0
			chapters: z.array(
				z.object({
					title: z.string(),
					slug: z.string(), // mdファイル名（拡張子なし）
					free: z.boolean().default(true),
				})
			),
		}),
});

// レガシーのblogコレクション（後で削除予定）
const blog = defineCollection({
	loader: glob({ base: './src/content/blog', pattern: '**/*.{md,mdx}' }),
	schema: ({ image }) =>
		z.object({
			title: z.string(),
			description: z.string(),
			pubDate: z.coerce.date(),
			updatedDate: z.coerce.date().optional(),
			heroImage: image().optional(),
		}),
});

export const collections = { articles, books, blog };
