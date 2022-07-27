<script lang="ts">
  import Email from '$lib/icons/email.svelte';
  import Github from '$lib/icons/github.svelte';
  import LinkedIn from '$lib/icons/linkedin.svelte';
  import Whatsapp from '$lib/icons/whatsapp.svelte';
  import CaretLeft from '$lib/icons/caret-left.svelte';
  import CaretRight from '$lib/icons/caret-right.svelte';
  import '../styles/globals.css';
  import '../styles/reset.css';

  let maximized: boolean = true;

  function handleClick(): void {
    maximized = !maximized;
  }
</script>

<div id="root" data-testid="root">
  <div class="sidebar" class:collapse={!maximized} data-testid="sidebar">
    <header>
      <img src="/avatar.png" alt="A manga-style drawing of Marill" />
      <h1>Lucas Harada</h1>
      <h2>Software Engineer</h2>
    </header>

    <nav>
      <a href="/">Home</a>
      <a href="/posts">Posts</a>
      <a href="/projects">Projects</a>
      <a href="/resume">Resume</a>
    </nav>

    <footer>
      <address>
        <a href="https://www.linkedin.com/in/lucas-harada/"><LinkedIn /> Lucas Harada</a>
        <a href="mailto:lucasyharada@gmail.com"><Email /> lucasyharada@gmail.com</a>
        <a href="https://wa.me/5511995934114"><Whatsapp /> +55 (11) 99593-4114</a>
        <a href="https://github.com/adarah"><Github /> adarah</a>
      </address>
    </footer>
  </div>
  <div class="button">
    {#if maximized}
      <CaretLeft on:click={handleClick} />
    {:else}
      <CaretRight on:click={handleClick} />
    {/if}
  </div>
  <main>
    <slot />
  </main>
</div>

<style>
  #root {
    display: flex;
    height: 100%;
    --sidebar-width: 250px;
    --padding-top: 50px;
    --padding-bottom: 30px;
    --button-size: 30px
  }
  main {
    padding-top: var(--padding-top);
    padding-bottom: var(--padding-bottom);
    padding-right: var(--button-size);
  }

  .sidebar {
    display: flex;
    flex-direction: column;
    align-items: center;
    border: solid 1px brown;
    background-color: antiquewhite;
    padding-bottom: var(--padding-bottom);
    flex-grow: 0;
    flex-shrink: 0;

    width: var(--sidebar-width);

    transition-property: margin-left, opacity, visibility;
    transition-duration: 0.4s;
    transition-timing-function: ease;

    margin-left: 0;
    opacity: 1;
    visibility: visible;
  }

  .collapse {
    margin-left: calc(-1 * var(--sidebar-width));
    opacity: 0;
    visibility: hidden;
  }

  .sidebar a {
    display: block;
  }
  .sidebar header h1 {
    flex-grow: 1;
    margin-top: 10px
  }
  .sidebar nav {
    /* background-color: green; */
    display: flex;
    justify-content: center;
    flex-direction: column;
    flex-grow: 1;
    font-size: x-large;
  }

  .sidebar a:visited {
    /* Keeps the color for visited links the same as the unvisited */
    /* https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#system_colors */
    color: LinkText;
  }

  address :global(svg) {
    height: 1em;
    display: inline;
    vertical-align: text-bottom;
  }

  main {
    width: 90%;
    max-width: 700px;
    margin: 0 auto;
  }

  .button {
    flex-shrink: 0;
    flex-grow: 0;
    transform: translateX(-8px);
    align-self: center;
    background-color: aliceblue;
    border: solid 1px gray;
    border-radius: 100%;
    width: var(--button-size);
    transition: background-color 0.3s;
  }
  .button :global(svg) {
    vertical-align: center;
    width: var(--button-size);
    height: var(--button-size);
  }

  .button:hover {
    background-color: gray;
  }
</style>
