<script context="module" lang="ts">
  interface SeoImage {
    url: string;
    alt: string;
    width: string;
    height: string;
  }
</script>

<script lang="ts">
  export let canonicalUrl: string;
  export let title: string;
  export let description: string;
  export let image: SeoImage;
  export let ogType: string;
</script>

<svelte:head>
  <link rel="canonical" href={canonicalUrl} />

  <!-- OpenGraph Tags -->
  <meta property="og:title" content={title} />
  <meta property="og:type" content={ogType} />
  <meta property="og:url" content={canonicalUrl} />
  <meta property="og:locale" content="en-US" />
  <meta property="og:image" content={image.url} />
  <meta property="og:image:secure_url" content={image.url} />
  <meta property="og:image:alt" content={image.alt} />
  <meta property="og:image:width" content={image.width} />
  <meta property="og:image:height" content={image.height} />
  <meta property="og:description" name="description" content={description} />
  <meta property="og:site_name" content="Lucas Harada's blog" />

  <!-- Twitter Tags -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={image.url} />
  <meta name="twitter:image:alt" content={image.alt} />
</svelte:head>
