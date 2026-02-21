"use client";

import { useChat } from "@/contexts/ChatContext";
import { MODELS } from "@/lib/constants";
import { ModelId } from "@/types/chat";

export function ModelSelector() {
  const { activeModel, setActiveModel } = useChat();

  return (
    <div className="flex items-center gap-2">
      <span className="text-xs text-dark-400">Model:</span>
      <select
        value={activeModel}
        onChange={(e) => setActiveModel(e.target.value as ModelId)}
        className="rounded-lg border border-dark-600 bg-dark-800 px-3 py-1.5 text-sm text-white focus:outline-none focus:ring-2 focus:ring-blue-500 hover:border-dark-500 transition-colors cursor-pointer"
      >
        {MODELS.map((model) => (
          <option key={model.id} value={model.id}>
            {model.name}
          </option>
        ))}
      </select>
    </div>
  );
}
