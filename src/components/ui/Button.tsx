'use client';

import { motion } from 'framer-motion';
import React from 'react';

export default function Button({ children, variant = 'default', onClick }: { children: React.ReactNode; variant?: 'default' | 'primary' | 'ghost'; onClick?: () => void }) {
  const base = 'btn-tibia';
  const cls = variant === 'primary' ? `${base} btn-tibia--primary` : base;

  return (
    <motion.button
      initial={{ scale: 1 }}
      whileTap={{ scale: 0.985 }}
      whileHover={{ scale: 1.02 }}
      transition={{ duration: 0.14 }}
      onClick={onClick}
      className={cls}
    >
      {children}
    </motion.button>
  );
}
