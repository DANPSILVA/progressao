import { NextConfig } from 'next';

const nextConfig: NextConfig = {
  experimental: {
    appDir: true
  },
  typescript: {
    ignoreBuildErrors: false
  }
};

export default nextConfig;
