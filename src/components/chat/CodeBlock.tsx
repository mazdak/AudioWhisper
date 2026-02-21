"use client";

import { useState } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { oneDark } from "react-syntax-highlighter/dist/esm/styles/prism";
import { useEditor } from "@/contexts/EditorContext";
import { normalizeLanguage } from "@/lib/languages";

interface CodeBlockProps {
  code: string;
  language: string;
  messageId?: string;
}

export function CodeBlock({ code, language, messageId }: CodeBlockProps) {
  const [copied, setCopied] = useState(false);
  const { openCodeInEditor } = useEditor();
  const normalizedLang = normalizeLanguage(language);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleOpenInEditor = () => {
    openCodeInEditor(code, normalizedLang, messageId);
  };

  return (
    <div className="my-3 rounded-lg overflow-hidden border border-dark-700">
      <div className="flex items-center justify-between bg-dark-800 px-4 py-2">
        <span className="text-xs text-dark-400 font-mono">{normalizedLang}</span>
        <div className="flex items-center gap-2">
          <button
            onClick={handleCopy}
            className="text-xs text-dark-400 hover:text-white transition-colors px-2 py-1 rounded hover:bg-dark-700"
          >
            {copied ? "Copied!" : "Copy"}
          </button>
          <button
            onClick={handleOpenInEditor}
            className="text-xs text-blue-400 hover:text-blue-300 transition-colors px-2 py-1 rounded hover:bg-dark-700"
          >
            Open in Editor
          </button>
        </div>
      </div>
      <SyntaxHighlighter
        language={normalizedLang}
        style={oneDark}
        customStyle={{
          margin: 0,
          borderRadius: 0,
          fontSize: "0.875rem",
          background: "#0d1117",
        }}
      >
        {code}
      </SyntaxHighlighter>
    </div>
  );
}
