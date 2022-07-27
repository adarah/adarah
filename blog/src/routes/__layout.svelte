<script lang="ts">
  import Email from '$lib/icons/email.svelte';
  import Github from '$lib/icons/github.svelte';
  import LinkedIn from '$lib/icons/linkedin.svelte';
  import Whatsapp from '$lib/icons/whatsapp.svelte';
  import '../styles/globals.css';
  import '../styles/reset.css';

  let maximized: boolean = true;

  function handleClick(): void {
    maximized = !maximized;
  }
</script>

<div id="root" data-testid="root">
  <div class="sidebar" class:collapse={!maximized} data-testid="sidebar">
    <img src="/placeholder.jpeg" alt="My face" />
    <h1>Lucas Harada</h1>
    <h2>Software Engineer @ Trilogy</h2>

    <nav>
      <a href="/">Home</a>
      <a href="/posts">Posts</a>
      <a href="/projects">Projects</a>
      <a href="/resume">Resume</a>
    </nav>

    <address>
      <a href="https://www.linkedin.com/in/lucas-harada/"><LinkedIn /> Lucas Harada</a>
      <a href="mailto:lucasyharada@gmail.com"><Email /> lucasyharada@gmail.com</a>
      <a href="https://wa.me/5511995934114"><Whatsapp /> +55 (11) 99593-4114</a>
      <a href="https://github.com/adarah"><Github /> adarah</a>
    </address>
  </div>
  <button on:click={handleClick} title={maximized ? 'Hide sidebar' : 'Show sidebar'}>
    {maximized ? '◀' : '▶'}
  </button>
  <main>
    <slot />
  </main>
</div>

<style>
  #root {
    display: flex;
    height: 100%;
    --sidebar-width: 350px;
  }

  .sidebar {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: var(--sidebar-width);
    transition-property: margin-left, opacity, visibility;
    transition-duration: 0.5s;
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
</style>
