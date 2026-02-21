"use client";

import { createContext, useContext, useState, useCallback, ReactNode } from "react";
import { EditorTab } from "@/types/editor";
import { generateId } from "@/lib/utils";
import { normalizeLanguage } from "@/lib/languages";

interface EditorContextValue {
  tabs: EditorTab[];
  activeTabId: string | null;
  openCodeInEditor: (code: string, language: string, messageId?: string) => void;
  updateTabContent: (tabId: string, content: string) => void;
  closeTab: (tabId: string) => void;
  setActiveTab: (tabId: string) => void;
  createNewTab: (language?: string) => void;
  setTabLanguage: (tabId: string, language: string) => void;
  activeTab: EditorTab | null;
}

const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorProvider({ children }: { children: ReactNode }) {
  const [tabs, setTabs] = useState<EditorTab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);

  const activeTab = tabs.find((t) => t.id === activeTabId) ?? null;

  const openCodeInEditor = useCallback((code: string, language: string, messageId?: string) => {
    const lang = normalizeLanguage(language);
    const id = generateId();
    const tab: EditorTab = {
      id,
      label: lang.charAt(0).toUpperCase() + lang.slice(1),
      language: lang,
      content: code,
      sourceMessageId: messageId,
    };
    setTabs((prev) => [...prev, tab]);
    setActiveTabId(id);
  }, []);

  const updateTabContent = useCallback((tabId: string, content: string) => {
    setTabs((prev) => prev.map((t) => (t.id === tabId ? { ...t, content } : t)));
  }, []);

  const closeTab = useCallback(
    (tabId: string) => {
      setTabs((prev) => {
        const filtered = prev.filter((t) => t.id !== tabId);
        if (activeTabId === tabId) {
          setActiveTabId(filtered.length > 0 ? filtered[filtered.length - 1].id : null);
        }
        return filtered;
      });
    },
    [activeTabId]
  );

  const setActiveTab = useCallback((tabId: string) => {
    setActiveTabId(tabId);
  }, []);

  const createNewTab = useCallback((language = "typescript") => {
    const id = generateId();
    const tab: EditorTab = {
      id,
      label: "Untitled",
      language,
      content: "",
    };
    setTabs((prev) => [...prev, tab]);
    setActiveTabId(id);
  }, []);

  const setTabLanguage = useCallback((tabId: string, language: string) => {
    setTabs((prev) => prev.map((t) => (t.id === tabId ? { ...t, language } : t)));
  }, []);

  return (
    <EditorContext.Provider
      value={{
        tabs,
        activeTabId,
        openCodeInEditor,
        updateTabContent,
        closeTab,
        setActiveTab,
        createNewTab,
        setTabLanguage,
        activeTab,
      }}
    >
      {children}
    </EditorContext.Provider>
  );
}

export function useEditor() {
  const context = useContext(EditorContext);
  if (!context) throw new Error("useEditor must be used within EditorProvider");
  return context;
}
