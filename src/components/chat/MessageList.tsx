"use client";

import { useEffect, useRef } from "react";
import { useChat } from "@/contexts/ChatContext";
import { MessageBubble } from "./MessageBubble";

export function MessageList() {
  const { activeConversation, isStreaming } = useChat();
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [activeConversation?.messages, isStreaming]);

  if (!activeConversation || activeConversation.messages.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="text-center">
          <h3 className="text-xl font-semibold text-dark-300 mb-2">Start a conversation</h3>
          <p className="text-dark-500 text-sm max-w-md">
            Ask me anything about coding. I can help with React, Python, APIs, SQL, and more.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4 scrollbar-thin">
      {activeConversation.messages.map((message) => (
        <MessageBubble key={message.id} message={message} />
      ))}
      <div ref={bottomRef} />
    </div>
  );
}
