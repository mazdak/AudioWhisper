import { cn } from "@/lib/utils";

interface BadgeProps {
  children: React.ReactNode;
  variant?: "default" | "success" | "warning" | "info";
  className?: string;
}

export function Badge({ children, variant = "default", className }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
        {
          "bg-dark-700 text-dark-300": variant === "default",
          "bg-green-500/10 text-green-400": variant === "success",
          "bg-amber-500/10 text-amber-400": variant === "warning",
          "bg-blue-500/10 text-blue-400": variant === "info",
        },
        className
      )}
    >
      {children}
    </span>
  );
}
