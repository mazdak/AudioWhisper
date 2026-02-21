import { ModelOption } from "@/types/chat";

export const APP_NAME = "CodeAssist AI";

export const MODELS: ModelOption[] = [
  { id: "claude-sonnet", name: "Claude Sonnet", provider: "Anthropic" },
  { id: "gpt-4o", name: "GPT-4o", provider: "OpenAI" },
  { id: "gemini-pro", name: "Gemini Pro", provider: "Google" },
];

export const FREE_MESSAGE_LIMIT = 10;
export const FREE_CONVERSATION_LIMIT = 3;

export const SUPPORTED_LANGUAGES = [
  "typescript", "javascript", "python", "java", "csharp", "cpp",
  "go", "rust", "ruby", "php", "swift", "kotlin", "html", "css",
  "sql", "bash", "json", "yaml", "markdown", "plaintext",
] as const;
