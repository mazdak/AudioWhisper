"use client";

import dynamic from "next/dynamic";

const MonacoEditor = dynamic(() => import("@monaco-editor/react"), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-full bg-dark-900">
      <div className="text-dark-400 text-sm">Loading editor...</div>
    </div>
  ),
});

interface EditorWrapperProps {
  value: string;
  language: string;
  onChange: (value: string) => void;
}

export function EditorWrapper({ value, language, onChange }: EditorWrapperProps) {
  return (
    <MonacoEditor
      height="100%"
      language={language}
      value={value}
      onChange={(val) => onChange(val ?? "")}
      theme="vs-dark"
      options={{
        minimap: { enabled: false },
        fontSize: 14,
        fontFamily: "'JetBrains Mono', monospace",
        wordWrap: "on",
        automaticLayout: true,
        padding: { top: 16 },
        scrollBeyondLastLine: false,
        renderLineHighlight: "gutter",
        bracketPairColorization: { enabled: true },
      }}
    />
  );
}
