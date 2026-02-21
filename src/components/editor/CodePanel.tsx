"use client";

import { useEditor } from "@/contexts/EditorContext";
import { EditorWrapper } from "./EditorWrapper";
import { EditorTabs } from "./EditorTabs";
import { EditorToolbar } from "./EditorToolbar";

export function CodePanel() {
  const { activeTab, updateTabContent, tabs } = useEditor();

  return (
    <div className="flex flex-col h-full bg-dark-900">
      <EditorToolbar />
      <EditorTabs />
      {activeTab ? (
        <div className="flex-1">
          <EditorWrapper
            value={activeTab.content}
            language={activeTab.language}
            onChange={(value) => updateTabContent(activeTab.id, value)}
          />
        </div>
      ) : (
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <div className="text-4xl mb-3 text-dark-600">{"</>"}</div>
            <h3 className="text-sm font-medium text-dark-400 mb-1">No files open</h3>
            <p className="text-xs text-dark-500">
              Click &quot;Open in Editor&quot; on a code block or create a new tab
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
