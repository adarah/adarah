<script lang="ts">
  import Email from '$lib/icons/email.svelte';
  import Github from '$lib/icons/github.svelte';
  import LinkedIn from '$lib/icons/linkedin.svelte';
  import Whatsapp from '$lib/icons/whatsapp.svelte';

  export let open: boolean = true;
</script>

  <div class="sidebar" class:collapse={!open} data-testid="sidebar">
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
        <a href="https://www.linkedin.com/in/lucas-harada/"><LinkedIn /> lucas-harada</a>
        <a href="mailto:lucasyharada@gmail.com"><Email /> lucasYharada@gmail.com</a>
        <a href="https://wa.me/5511995934114"><Whatsapp /> +55 (11) 99593-4114</a>
        <a href="https://github.com/adarah"><Github /> adarah</a>
      </address>
    </footer>
  </div>

<style>
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
    margin-top: 10px;
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
</style>
