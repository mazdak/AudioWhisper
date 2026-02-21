import { AuthGate } from "@/components/layout/AuthGate";
import { Navbar } from "@/components/layout/Navbar";

export default function MainLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthGate>
      <div className="flex flex-col h-screen">
        <Navbar />
        <div className="flex-1 overflow-hidden">
          {children}
        </div>
      </div>
    </AuthGate>
  );
}
