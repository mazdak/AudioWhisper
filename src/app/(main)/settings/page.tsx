"use client";

import { useAuth } from "@/contexts/AuthContext";
import { useSubscription } from "@/contexts/SubscriptionContext";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Avatar } from "@/components/ui/Avatar";
import { useRouter } from "next/navigation";

export default function SettingsPage() {
  const { user, logout } = useAuth();
  const { tier, isPro } = useSubscription();
  const router = useRouter();

  const handleLogout = async () => {
    await logout();
    router.push("/");
  };

  if (!user) return null;

  return (
    <div className="max-w-2xl mx-auto px-4 py-12">
      <h1 className="text-2xl font-bold text-white mb-8">Settings</h1>

      <Card className="mb-6">
        <div className="flex items-center gap-4 mb-6">
          <Avatar name={user.name} className="h-14 w-14 text-lg" />
          <div>
            <h2 className="text-lg font-semibold text-white">{user.name}</h2>
            <p className="text-sm text-dark-400">{user.email}</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-sm text-dark-400">Plan:</span>
          <Badge variant={isPro ? "success" : "default"}>
            {isPro ? "Pro" : "Free"}
          </Badge>
          {!isPro && (
            <Button size="sm" onClick={() => router.push("/pricing")}>
              Upgrade
            </Button>
          )}
        </div>
      </Card>

      <Card>
        <h3 className="text-sm font-medium text-dark-300 mb-4">Account</h3>
        <Button variant="danger" onClick={handleLogout}>
          Sign Out
        </Button>
      </Card>
    </div>
  );
}
