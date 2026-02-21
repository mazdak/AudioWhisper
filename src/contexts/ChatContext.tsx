"use client";

import { createContext, useContext, useState, useCallback, ReactNode, useRef } from "react";
import { Message, Conversation, ModelId } from "@/types/chat";
import { generateId } from "@/lib/utils";
import { useLocalStorage } from "@/hooks/useLocalStorage";
import { streamChat } from "@/lib/api";

interface ChatContextValue {
  conversations: Conversation[];
  activeConversationId: string | null;
  activeModel: ModelId;
  isStreaming: boolean;
  setActiveModel: (model: ModelId) => void;
  createConversation: () => string;
  deleteConversation: (id: string) => void;
  setActiveConversation: (id: string) => void;
  sendMessage: (content: string) => Promise<void>;
  activeConversation: Conversation | null;
}

const ChatContext = createContext<ChatContextValue | null>(null);

export function ChatProvider({ children }: { children: ReactNode }) {
  const [conversations, setConversations] = useLocalStorage<Conversation[]>("chat-conversations", []);
  const [activeConversationId, setActiveConversationId] = useState<string | null>(null);
  const [activeModel, setActiveModel] = useState<ModelId>("claude-sonnet");
  const [isStreaming, setIsStreaming] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const activeConversation = conversations.find((c) => c.id === activeConversationId) ?? null;

  const createConversation = useCallback(() => {
    const id = generateId();
    const newConv: Conversation = {
      id,
      title: "New Chat",
      messages: [],
      model: activeModel,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    setConversations((prev) => [newConv, ...prev]);
    setActiveConversationId(id);
    return id;
  }, [activeModel, setConversations]);

  const deleteConversation = useCallback(
    (id: string) => {
      setConversations((prev) => prev.filter((c) => c.id !== id));
      if (activeConversationId === id) {
        setActiveConversationId(null);
      }
    },
    [activeConversationId, setConversations]
  );

  const setActiveConversation = useCallback((id: string) => {
    setActiveConversationId(id);
  }, []);

  const sendMessage = useCallback(
    async (content: string) => {
      if (isStreaming) return;

      let convId = activeConversationId;
      if (!convId) {
        convId = generateId();
        const newConv: Conversation = {
          id: convId,
          title: content.substring(0, 50),
          messages: [],
          model: activeModel,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        };
        setConversations((prev) => [newConv, ...prev]);
        setActiveConversationId(convId);
      }

      const userMessage: Message = {
        id: generateId(),
        role: "user",
        content,
        timestamp: Date.now(),
      };

      const assistantMessage: Message = {
        id: generateId(),
        role: "assistant",
        content: "",
        model: activeModel,
        timestamp: Date.now(),
      };

      setConversations((prev) =>
        prev.map((c) => {
          if (c.id !== convId) return c;
          const updated = {
            ...c,
            title: c.messages.length === 0 ? content.substring(0, 50) : c.title,
            messages: [...c.messages, userMessage, assistantMessage],
            updatedAt: Date.now(),
          };
          return updated;
        })
      );

      setIsStreaming(true);
      const controller = new AbortController();
      abortRef.current = controller;

      try {
        const allMessages = [
          ...(conversations.find((c) => c.id === convId)?.messages ?? []),
          userMessage,
        ].map((m) => ({ role: m.role, content: m.content }));

        await streamChat(
          allMessages,
          activeModel,
          (chunk) => {
            setConversations((prev) =>
              prev.map((c) => {
                if (c.id !== convId) return c;
                const msgs = [...c.messages];
                const lastMsg = msgs[msgs.length - 1];
                if (lastMsg && lastMsg.role === "assistant") {
                  msgs[msgs.length - 1] = { ...lastMsg, content: lastMsg.content + chunk };
                }
                return { ...c, messages: msgs };
              })
            );
          },
          controller.signal
        );
      } catch (err) {
        if (err instanceof Error && err.name !== "AbortError") {
          console.error("Chat error:", err);
        }
      } finally {
        setIsStreaming(false);
        abortRef.current = null;
      }
    },
    [activeConversationId, activeModel, conversations, isStreaming, setConversations]
  );

  return (
    <ChatContext.Provider
      value={{
        conversations,
        activeConversationId,
        activeModel,
        isStreaming,
        setActiveModel,
        createConversation,
        deleteConversation,
        setActiveConversation,
        sendMessage,
        activeConversation,
      }}
    >
      {children}
    </ChatContext.Provider>
  );
}

export function useChat() {
  const context = useContext(ChatContext);
  if (!context) throw new Error("useChat must be used within ChatProvider");
  return context;
}
