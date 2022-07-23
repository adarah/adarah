/// <reference types="@sveltejs/kit" />
/// <reference types="@cloudflare/workers-types" />


// See https://kit.svelte.dev/docs/types#app
// for information about these interfaces
// and what to do when importing types
declare namespace App {
	// interface Locals {}
	interface Platform {
		env: {
			'chip-8': R2Bucket
		}
	}
	// interface Session {}
	// interface Stuff {}
}
