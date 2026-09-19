import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Static export: `next build` emits a plain HTML/CSS/JS tree in out/,
  // which is what Cloudflare Pages serves. No Node runtime is involved, so
  // server actions, route handlers, ISR and middleware are unavailable.
  output: "export",

  // The default image optimiser needs a server; static export cannot use it.
  images: { unoptimized: true },

  // Emit about/index.html rather than about.html, so URLs work identically
  // with and without the trailing slash on a static host.
  trailingSlash: true,
};

export default nextConfig;
