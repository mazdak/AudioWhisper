"use client";

import { ModelSelector } from "./ModelSelector";
import { MessageList } from "./MessageList";
import { ChatInput } from "./ChatInput";

export function ChatPanel() {
  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between border-b border-dark-700 px-4 py-3">
        <h2 className="text-sm font-semibold text-dark-200">Chat</h2>
        <ModelSelector />
      </div>
      <MessageList />
      <ChatInput />
    </div>
  );
}
