<script context="module" lang="ts">
  import type { Load } from './__types/__layout';

  // This load function is used to expose frontmatter metadata to the layout files above
  export const load: Load = async ({ url, fetch }) => {
    // Do not attempt to fetch post if we are requesting /posts
    // That path is only for listing them
    if (url.pathname === '/posts') {
      return { status: 200 };
    }
    const post = await fetch(`${url.pathname}.json`).then((r) => r.json());
    return {
      status: 200,
      props: {
        post,
      },
      stuff: {
        post
      }
    };
  };
</script>

<script lang="ts">
  import Title from '$lib/title.svelte';
  import '../../styles/one-dark.css';
  import type { PostFrontmatter } from './post';
  // Is only undefined if we are on the /posts route
  export let post: PostFrontmatter | undefined;
</script>

{#if post !== undefined}
  <Title title={post.title} />
  <h1>{post.title}</h1>
  <p>on: <time>{post.date}</time></p>
{/if}

<slot />
