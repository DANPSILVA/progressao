'use client';

import React from 'react';
import { motion } from 'framer-motion';

export default function StatCard({ title, value, subtitle, accent = false }: { title: string; value: number | string; subtitle?: string; accent?: boolean }) {
  return (
    <motion.div whileHover={{ y: -4 }} className="theme-glass p-4 rounded-md">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-xs text-muted-300">{title}</div>
          <div className={`text-lg font-semibold ${accent ? 'text-accent' : 'text-[var(--text-100)]'}`}>{typeof value === 'number' ? value.toLocaleString() : value}</div>
        </div>
        <div className="text-sm text-muted-300">{subtitle}</div>
      </div>
    </motion.div>
  );
}
