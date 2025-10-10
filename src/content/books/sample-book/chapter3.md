# コンポーネントの作成

Astroコンポーネントの基本的な作り方を学びます。

## 基本構文

```astro
---
// JavaScriptロジック
const greeting = "Hello, Astro!";
---

<div>
  <h1>{greeting}</h1>
</div>
```

## Propsの使用

```astro
---
interface Props {
  title: string;
}

const { title } = Astro.props;
---

<h1>{title}</h1>
```

## まとめ

Astroコンポーネントは直感的で使いやすい構文を持っています。
