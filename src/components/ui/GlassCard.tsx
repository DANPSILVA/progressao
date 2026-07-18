'use client';

import { motion } from 'framer-motion';
import React from 'react';

export default function GlassCard({ title, children, footer }: { title?: React.ReactNode; children: React.ReactNode; footer?: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.18 }}
      className="theme-glass p-6"
    >
      {title && <div className="text-sm text-muted-300 mb-3">{title}</div>}
      <div>{children}</div>
      {footer && <div className="mt-4 text-sm text-muted-300">{footer}</div>}
    </motion.div>
  );
}
