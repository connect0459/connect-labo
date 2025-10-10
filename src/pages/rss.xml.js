import { getCollection } from 'astro:content';
import rss from '@astrojs/rss';
import { SITE_DESCRIPTION, SITE_TITLE } from '../consts';

export async function GET(context) {
	const articles = await getCollection('articles');
	return rss({
		title: SITE_TITLE,
		description: SITE_DESCRIPTION,
		site: context.site,
		items: articles.map((article) => ({
			...article.data,
			link: `/articles/${article.id}/`,
		})),
	});
}
