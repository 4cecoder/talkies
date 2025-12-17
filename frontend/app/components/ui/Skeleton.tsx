import { HTMLAttributes } from "react";
import { cn } from "@/app/lib/utils";

interface SkeletonProps extends HTMLAttributes<HTMLDivElement> {
  variant?: "text" | "circular" | "rectangular";
  width?: string | number;
  height?: string | number;
}

function Skeleton({
  className,
  variant = "rectangular",
  width,
  height,
  style,
  ...props
}: SkeletonProps) {
  const baseStyles = cn(
    "animate-pulse bg-gradient-to-r from-background-card via-white/10 to-background-card",
    "bg-[length:200%_100%] animate-gradient-fast"
  );

  const variants = {
    text: "h-4 rounded",
    circular: "rounded-full",
    rectangular: "rounded-card",
  };

  return (
    <div
      className={cn(baseStyles, variants[variant], className)}
      style={{
        width: width,
        height: height,
        ...style,
      }}
      role="status"
      aria-label="Loading..."
      aria-live="polite"
      {...props}
    />
  );
}

function SkeletonCard() {
  return (
    <div className="rounded-card bg-background-card border-border border p-6">
      <div className="space-y-4">
        <Skeleton variant="rectangular" height="24px" width="60%" />
        <Skeleton variant="text" height="16px" width="100%" />
        <Skeleton variant="text" height="16px" width="80%" />
        <div className="flex items-center gap-4 pt-4">
          <Skeleton variant="circular" width="40px" height="40px" />
          <div className="flex-1 space-y-2">
            <Skeleton variant="text" height="14px" width="40%" />
            <Skeleton variant="text" height="12px" width="60%" />
          </div>
        </div>
      </div>
    </div>
  );
}

function SkeletonButton({ width = "120px" }: { width?: string }) {
  return <Skeleton height="44px" width={width} className="rounded-button" />;
}

function SkeletonAvatar({ size = 40 }: { size?: number }) {
  return <Skeleton variant="circular" width={size} height={size} />;
}

export { Skeleton, SkeletonCard, SkeletonButton, SkeletonAvatar };
