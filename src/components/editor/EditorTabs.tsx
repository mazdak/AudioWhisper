"use client";

import { useEditor } from "@/contexts/EditorContext";
import { cn } from "@/lib/utils";

export function EditorTabs() {
  const { tabs, activeTabId, setActiveTab, closeTab } = useEditor();

  if (tabs.length === 0) return null;

  return (
    <div className="flex items-center border-b border-dark-700 bg-dark-900 overflow-x-auto scrollbar-thin">
      {tabs.map((tab) => (
        <div
          key={tab.id}
          className={cn(
            "flex items-center gap-2 px-4 py-2 text-xs border-r border-dark-700 cursor-pointer transition-colors shrink-0",
            tab.id === activeTabId
              ? "bg-dark-800 text-white"
              : "text-dark-400 hover:text-dark-200 hover:bg-dark-800/50"
          )}
          onClick={() => setActiveTab(tab.id)}
        >
          <span>{tab.label}</span>
          <button
            onClick={(e) => {
              e.stopPropagation();
              closeTab(tab.id);
            }}
            className="text-dark-500 hover:text-white transition-colors"
          >
            <svg className="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
      ))}
    </div>
  );
}
