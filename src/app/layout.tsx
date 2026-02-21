import type { Metadata } from "next";
import { AuthProvider } from "@/contexts/AuthContext";
import { SubscriptionProvider } from "@/contexts/SubscriptionContext";
import { ChatProvider } from "@/contexts/ChatContext";
import { EditorProvider } from "@/contexts/EditorContext";
import "./globals.css";

export const metadata: Metadata = {
  title: "CodeAssist AI - AI-Powered Coding Assistant",
  description: "Chat with AI models and edit code in an integrated workspace.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="font-sans">
        <AuthProvider>
          <SubscriptionProvider>
            <ChatProvider>
              <EditorProvider>{children}</EditorProvider>
            </ChatProvider>
          </SubscriptionProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
