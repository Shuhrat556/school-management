/** @type {import('next').NextConfig} */
const nextConfig = {
  // Self-contained server in .next/standalone (used by the Dockerfile): only the files it needs, no full node_modules.
  output: 'standalone',
  poweredByHeader: false,
  async headers() {
    // Baseline hardening for every page (OWASP Secure Headers). HSTS waits for TLS (BUGS B14).
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
    ];
  },
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
