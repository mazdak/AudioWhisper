"use client";

import { useChat } from "@/contexts/ChatContext";
import { cn, truncate, formatTimestamp } from "@/lib/utils";

export function Sidebar() {
  const {
    conversations,
    activeConversationId,
    createConversation,
    deleteConversation,
    setActiveConversation,
  } = useChat();

  return (
    <aside className="w-64 border-r border-dark-700 bg-dark-900 flex flex-col h-full shrink-0">
      <div className="p-3">
        <button
          onClick={createConversation}
          className="w-full flex items-center justify-center gap-2 rounded-lg border border-dark-600 bg-dark-800 px-4 py-2.5 text-sm text-dark-200 hover:bg-dark-700 transition-colors"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
          </svg>
          New Chat
        </button>
      </div>
      <div className="flex-1 overflow-y-auto px-2 pb-2 scrollbar-thin">
        {conversations.length === 0 ? (
          <p className="text-xs text-dark-500 text-center mt-8 px-4">
            No conversations yet. Start a new chat!
          </p>
        ) : (
          conversations.map((conv) => (
            <div
              key={conv.id}
              onClick={() => setActiveConversation(conv.id)}
              className={cn(
                "group flex items-center justify-between rounded-lg px-3 py-2.5 mb-1 cursor-pointer transition-colors",
                conv.id === activeConversationId
                  ? "bg-dark-700 text-white"
                  : "text-dark-400 hover:bg-dark-800 hover:text-dark-200"
              )}
            >
              <div className="flex-1 min-w-0">
                <p className="text-sm truncate">{truncate(conv.title, 30)}</p>
                <p className="text-xs text-dark-500 mt-0.5">
                  {formatTimestamp(conv.updatedAt)}
                </p>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteConversation(conv.id);
                }}
                className="opacity-0 group-hover:opacity-100 text-dark-500 hover:text-red-400 transition-all ml-2 shrink-0"
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          ))
        )}
      </div>
    </aside>
  );
}
