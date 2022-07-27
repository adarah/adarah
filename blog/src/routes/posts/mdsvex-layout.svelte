<script>
  export let title;
  export let date;
</script>

<h1>{title}</h1>
<p>on: <time>{date}</time></p>

<slot/>