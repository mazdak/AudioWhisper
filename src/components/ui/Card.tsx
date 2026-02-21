import { cn } from "@/lib/utils";

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <div
      className={cn(
        "rounded-xl border border-dark-700 bg-dark-800 p-6 shadow-lg",
        className
      )}
    >
      {children}
    </div>
  );
}
