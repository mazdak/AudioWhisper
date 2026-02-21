export interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  model?: string;
  timestamp: number;
}

export interface Conversation {
  id: string;
  title: string;
  messages: Message[];
  model: string;
  createdAt: number;
  updatedAt: number;
}

export type ModelId = "claude-sonnet" | "gpt-4o" | "gemini-pro";

export interface ModelOption {
  id: ModelId;
  name: string;
  provider: string;
}
