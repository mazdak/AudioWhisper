"use client";

import { Sidebar } from "@/components/layout/Sidebar";
import { ChatPanel } from "@/components/chat/ChatPanel";
import { CodePanel } from "@/components/editor/CodePanel";
import { useState } from "react";

export default function ChatPage() {
  const [editorVisible, setEditorVisible] = useState(true);

  return (
    <div className="flex h-full">
      <Sidebar />
      <div className="flex-1 flex min-w-0">
        <div className={editorVisible ? "w-1/2 border-r border-dark-700" : "w-full"}>
          <ChatPanel />
        </div>
        {editorVisible && (
          <div className="w-1/2">
            <CodePanel />
          </div>
        )}
      </div>
      <button
        onClick={() => setEditorVisible(!editorVisible)}
        className="fixed bottom-4 right-4 z-30 rounded-full bg-dark-700 border border-dark-600 p-2.5 text-dark-300 hover:text-white hover:bg-dark-600 transition-colors shadow-lg"
        title={editorVisible ? "Hide editor" : "Show editor"}
      >
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
        </svg>
      </button>
    </div>
  );
}
