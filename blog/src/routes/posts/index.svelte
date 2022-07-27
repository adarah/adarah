<script context="module" lang="ts">
  import type { Load } from './__types/index';
  export const load: Load = async ({ fetch }) => {
    const res = await fetch('/posts/list');
    if (res === null) {
      return {status: 404};
    }
    const articles = await res.json();
    console.log(articles);
    return {
      status: 200,
      props: {
        articles,
      },
    };
  };
</script>

<script lang="ts">
  import type { Article } from './list';
  export let articles: Article[];
  // console.log(articles);
</script>

{#each articles as { title, slug, date }}
  <p><a href={slug}>{title}</a></p>
  <p>{date}</p>
{/each}
