'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { LucideIcon } from 'lucide-react';

export default function StatCard({
  title,
  value,
  subtitle,
  icon: Icon,
  color = 'var(--series-1)',
}: {
  title: string;
  value: number | string;
  subtitle?: string;
  icon?: LucideIcon;
  color?: string;
}) {
  return (
    <motion.div whileHover={{ y: -4 }} className="theme-glass p-4 rounded-md flex items-center gap-3">
      {Icon && (
        <div
          className="flex items-center justify-center w-9 h-9 rounded-full shrink-0"
          style={{ backgroundColor: `color-mix(in srgb, ${color} 18%, transparent)`, color }}
        >
          <Icon className="w-4 h-4" />
        </div>
      )}
      <div className="min-w-0">
        <div className="text-xs text-muted-300 truncate">{title}</div>
        <div className="text-lg font-semibold text-[var(--text-100)] truncate">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>
        {subtitle && <div className="text-xs text-muted-300 truncate">{subtitle}</div>}
      </div>
    </motion.div>
  );
}
