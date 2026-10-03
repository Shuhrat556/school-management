/** @type {import('next').NextConfig} */
const nextConfig = {
  // Self-contained server in .next/standalone (used by the Dockerfile): only the files it needs, no full node_modules.
  output: 'standalone',
  async rewrites() {
    // Inside Docker: API_URL=http://api-gateway:8080
    // Local dev without Docker: API_URL=http://localhost:5001
    const apiBase = process.env.API_URL ?? 'http://localhost:5001';
    return [
      {
        source: '/api/:path*',
        destination: `${apiBase}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
