"use client";

import { useState } from "react";
import { useEditor } from "@/contexts/EditorContext";
import { SUPPORTED_LANGUAGES } from "@/lib/constants";
import { MONACO_LANGUAGE_MAP } from "@/lib/languages";

export function EditorToolbar() {
  const { activeTab, setTabLanguage, updateTabContent, createNewTab } = useEditor();
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    if (!activeTab) return;
    await navigator.clipboard.writeText(activeTab.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleClear = () => {
    if (!activeTab) return;
    updateTabContent(activeTab.id, "");
  };

  return (
    <div className="flex items-center justify-between border-b border-dark-700 px-4 py-2 bg-dark-900">
      <div className="flex items-center gap-3">
        <select
          value={activeTab?.language ?? "typescript"}
          onChange={(e) => {
            if (activeTab) {
              const lang = e.target.value;
              setTabLanguage(activeTab.id, MONACO_LANGUAGE_MAP[lang] ?? lang);
            }
          }}
          className="rounded border border-dark-600 bg-dark-800 px-2 py-1 text-xs text-white focus:outline-none focus:ring-1 focus:ring-blue-500 cursor-pointer"
        >
          {SUPPORTED_LANGUAGES.map((lang) => (
            <option key={lang} value={lang}>
              {lang.charAt(0).toUpperCase() + lang.slice(1)}
            </option>
          ))}
        </select>
      </div>
      <div className="flex items-center gap-2">
        <button
          onClick={() => createNewTab()}
          className="text-xs text-dark-400 hover:text-white transition-colors px-2 py-1 rounded hover:bg-dark-700"
        >
          + New
        </button>
        <button
          onClick={handleCopy}
          disabled={!activeTab}
          className="text-xs text-dark-400 hover:text-white transition-colors px-2 py-1 rounded hover:bg-dark-700 disabled:opacity-50"
        >
          {copied ? "Copied!" : "Copy"}
        </button>
        <button
          onClick={handleClear}
          disabled={!activeTab}
          className="text-xs text-dark-400 hover:text-white transition-colors px-2 py-1 rounded hover:bg-dark-700 disabled:opacity-50"
        >
          Clear
        </button>
      </div>
    </div>
  );
}
