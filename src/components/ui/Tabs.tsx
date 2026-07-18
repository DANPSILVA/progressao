'use client';

import React, { useState } from 'react';

export type TabItem = {
  key: string;
  label: string;
  content: React.ReactNode;
};

export default function Tabs({
  tabs,
  defaultTab,
  active: controlledActive,
  onActiveChange,
}: {
  tabs: TabItem[];
  defaultTab?: string;
  active?: string;
  onActiveChange?: (key: string) => void;
}) {
  const [internalActive, setInternalActive] = useState(defaultTab ?? tabs[0]?.key);
  const active = controlledActive ?? internalActive;

  const setActive = (key: string) => {
    setInternalActive(key);
    onActiveChange?.(key);
  };

  return (
    <div>
      <div role="tablist" className="flex gap-1 rounded-md bg-[rgba(255,255,255,0.02)] p-1 mb-6 w-fit">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            role="tab"
            aria-selected={active === tab.key}
            onClick={() => setActive(tab.key)}
            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
              active === tab.key ? 'bg-accent text-black' : 'text-muted-300 hover:text-[var(--text-100)]'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {tabs.map((tab) => (
        <div key={tab.key} role="tabpanel" hidden={active !== tab.key}>
          {active === tab.key && tab.content}
        </div>
      ))}
    </div>
  );
}
