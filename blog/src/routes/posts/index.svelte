<script context="module" lang="ts">
  import type { Load } from './__types/index';
  export const load: Load = async ({ fetch }) => {
    const res = await fetch('/posts.json');
    if (res === null) {
      return {status: 404};
    }
    const articles = await res.json();
    return {
      status: 200,
      props: {
        articles,
      },
    };
  };
</script>

<script lang="ts">
  import type { Article } from './index.json';
  export let articles: Article[];
</script>

{#each articles as { title, path, date, excerpt }}
  <p><a href={path}>{title}</a></p>
  <p>{excerpt}</p>
  <p>{date}</p>
{/each}
