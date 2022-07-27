<script context="module" lang="js">
  export const load = async () => {
    console.log('invoked!');
    return {
      status: 200,
    };
  };
</script>

<script lang="js">
  import Title from '$lib/title.svelte';
  import '../../styles/one-dark.css';
  export let title = 'Posts';
  export let date;
</script>

<Title {title} />

{#if date !== undefined}
  <h1>{title}</h1>
  <p>on: <time>{date}</time></p>
{/if}

<slot />
