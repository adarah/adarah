<script lang="ts">
	import '../styles/reset.css';
	import '../styles/globals.css';
</script>

<div data-testid="root">
	<section data-testid="sidebar">
		<img src="/placeholder.jpeg" alt="My face" />
		<h1>Lucas Harada</h1>
		<h2>Software Engineer @ Trilogy</h2>
	</section>

	<slot />
</div>
