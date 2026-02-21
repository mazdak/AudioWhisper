"use client";

import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { CodeBlock } from "./CodeBlock";
import type { Components } from "react-markdown";

interface MarkdownRendererProps {
  content: string;
  messageId?: string;
}

export function MarkdownRenderer({ content, messageId }: MarkdownRendererProps) {
  const components: Components = {
    code({ className, children, ...props }) {
      const match = /language-(\w+)/.exec(className || "");
      const codeString = String(children).replace(/\n$/, "");

      if (match) {
        return (
          <CodeBlock
            code={codeString}
            language={match[1]}
            messageId={messageId}
          />
        );
      }

      return (
        <code
          className="bg-dark-700 text-blue-300 px-1.5 py-0.5 rounded text-sm font-mono"
          {...props}
        >
          {children}
        </code>
      );
    },
    p({ children }) {
      return <p className="mb-3 last:mb-0 leading-relaxed">{children}</p>;
    },
    ul({ children }) {
      return <ul className="list-disc list-inside mb-3 space-y-1">{children}</ul>;
    },
    ol({ children }) {
      return <ol className="list-decimal list-inside mb-3 space-y-1">{children}</ol>;
    },
    h1({ children }) {
      return <h1 className="text-xl font-bold mb-3">{children}</h1>;
    },
    h2({ children }) {
      return <h2 className="text-lg font-bold mb-2">{children}</h2>;
    },
    h3({ children }) {
      return <h3 className="text-base font-semibold mb-2">{children}</h3>;
    },
    strong({ children }) {
      return <strong className="font-semibold text-white">{children}</strong>;
    },
    em({ children }) {
      return <em className="italic text-dark-300">{children}</em>;
    },
    a({ href, children }) {
      return (
        <a href={href} className="text-blue-400 hover:underline" target="_blank" rel="noopener noreferrer">
          {children}
        </a>
      );
    },
  };

  return (
    <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
      {content}
    </ReactMarkdown>
  );
}
