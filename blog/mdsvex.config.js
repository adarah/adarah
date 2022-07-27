import { defineMDSveXConfig as defineConfig } from 'mdsvex';

const config = defineConfig({
  extensions: ['.svelte.md', '.md', '.svx'],

  layout: {
    _: 'src/routes/posts/__layout.svelte',
  },
  smartypants: {
    dashes: 'oldschool',
  },

  remarkPlugins: [],
  rehypePlugins: [],
});

export default config;
