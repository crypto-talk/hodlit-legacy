# Hodlit production frontend on Lightsail

The Next.js container listens on `127.0.0.1:3000`. Caddy serves HTTPS on `origin-frontend.hodlit.xyz` and reads `HODLIT_ORIGIN_KEY` from its systemd environment file. CloudFront sends the same value as `X-Hodlit-Origin`. Update both when rotating the key.

CloudFront caches `/_next/static/*` and forwards `/api/v1/*` to `api.hodlit.xyz` with caching disabled. Dynamic pages use the Lightsail origin. Keep `hodlit.xyz` and its existing API and cookie paths during cutover.

GitHub Actions publishes images to ECR and calls the `HodlitDeployFrontend` Systems Manager document. The managed node runs `release.sh`, installed at `/usr/local/libexec/hodlit/deploy-frontend`. Reinstall the script on the node when changing it. The deployment verifies that Next.js responds locally and restarts the previous image if the new one fails the check.

Before the first production release, copy the production `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` and `NEXT_PUBLIC_ANALYTICS_*` / `NEXT_PUBLIC_POSTHOG_*` settings used on Vercel to GitHub Actions variables. For analytics or WalletConnect features already disabled on Vercel, leave the corresponding variables unset.

Run the workflow manually on `main` to validate the first image. Set `HODLIT_AWS_PRODUCTION_ENABLED` to `true` after checking the CloudFront preview and completing the DNS cutover to enable deployment on pushes to `main`.
