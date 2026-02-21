export interface EditorTab {
  id: string;
  label: string;
  language: string;
  content: string;
  sourceMessageId?: string;
}

export interface EditorState {
  tabs: EditorTab[];
  activeTabId: string | null;
}
