import type { NextConfig } from "next";
import withBundleAnalyzer from '@next/bundle-analyzer';

const bundleAnalyzer = withBundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
});

const nextConfig: NextConfig = {
  // Static export for GitHub Pages (no Node server / API routes available at runtime)
  output: 'export',

  // Production optimizations
  compress: true,
  poweredByHeader: false,
  reactStrictMode: true,

  // Image optimization
  // Static export doesn't support the default Next.js image optimization
  // loader (it requires a running server), so it must be disabled.
  images: {
    unoptimized: true,
  },

  // Bundle optimization
  experimental: {
    optimizePackageImports: ['lucide-react'],
  },

  // Performance budgets
  onDemandEntries: {
    maxInactiveAge: 25 * 1000,
    pagesBufferLength: 2,
  },

  // Turbopack configuration
  // Note: Turbopack handles browser/node package resolution differently than webpack
  // The webpack config below is maintained for explicit webpack builds
  turbopack: {},

  // Webpack configuration for Transformers.js (fallback)
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      sharp$: false,
      'onnxruntime-node$': false,
    };
    return config;
  },
};

export default bundleAnalyzer(nextConfig);
