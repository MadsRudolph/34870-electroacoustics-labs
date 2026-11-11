# Guide hosting

Live URL: https://labs.madsrudolph.dev/

Cloudflare Worker: `electroacoustics-guide`, with Workers Static Assets and a custom
domain. Only the guide is published; lab files are not in the deployment directory.
No home-server service is required. The page is public, with a request to search
engines not to index it (not access control).

Edit `../getting-started.html`, then from this folder:

```sh
npm ci
npx wrangler login # only if not already authenticated with Mads's account
npm run check
npm run deploy
```

The build copies the guide to `public/index.html` with response headers. Deployment
is manual; pushing a Git commit does not update the live site. `wrangler.jsonc`
records the account and custom domain so future deployments use the same target.

Reference: https://developers.cloudflare.com/workers/static-assets/get-started/
