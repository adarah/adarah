<script>
import Title from "$lib/title.svelte";
</script>

<Title title="Home"/>
<article>
  <header>
    <h1>Welcome to my blog!</h1>
    <figure data-testid="home-picture">
      <img src="/azumarill-marill-beach.jpeg" alt="Azumarill and marill at a beach" />
      <figcaption>
        Image by Artsy Theo via
        <a href="https://artsy-theo.tumblr.com/post/180738351293/azumarill-and-marill-at-the-beach">
          Tumblr
        </a>
      </figcaption>
    </figure>
  </header>
  <p>
    This is my personal site where I write down ideas, lessons learned, and whatever else comes to mind.
		It also just happens to be a great place for me to experiment with new technologies.
  </p>
</article>

<style>
	header {
		margin-bottom: 30px;
	}
</style>