import { HTMLAttributes } from 'react';
import { cn } from '@/app/lib/utils';

interface SkeletonProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'text' | 'circular' | 'rectangular';
  width?: string | number;
  height?: string | number;
}

function Skeleton({
  className,
  variant = 'rectangular',
  width,
  height,
  style,
  ...props
}: SkeletonProps) {
  const baseStyles = cn(
    'animate-pulse bg-gradient-to-r from-background-card via-white/10 to-background-card',
    'bg-[length:200%_100%] animate-gradient-fast'
  );

  const variants = {
    text: 'h-4 rounded',
    circular: 'rounded-full',
    rectangular: 'rounded-card',
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
    <div className="p-6 rounded-card bg-background-card border border-border">
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

function SkeletonButton({ width = '120px' }: { width?: string }) {
  return <Skeleton height="44px" width={width} className="rounded-button" />;
}

function SkeletonAvatar({ size = 40 }: { size?: number }) {
  return <Skeleton variant="circular" width={size} height={size} />;
}

function StatsSkeleton() {
  return (
    <section className="relative py-20 px-6">
      <div className="max-w-6xl mx-auto">
        <div className="grid md:grid-cols-4 gap-8">
          {[...Array(4)].map((_, i) => (
            <Skeleton key={i} height="160px" variant="rectangular" />
          ))}
        </div>
      </div>
    </section>
  );
}

function TestimonialsSkeleton() {
  return (
    <section className="relative py-20 px-6">
      <div className="max-w-6xl mx-auto">
        <Skeleton height="48px" width="384px" className="mx-auto mb-4" />
        <Skeleton height="24px" width="512px" className="mx-auto mb-16" />
        <div className="grid md:grid-cols-3 gap-8">
          {[...Array(3)].map((_, i) => (
            <Skeleton key={i} height="256px" variant="rectangular" />
          ))}
        </div>
      </div>
    </section>
  );
}

function FAQSkeleton() {
  return (
    <section className="relative py-20 px-6">
      <div className="max-w-3xl mx-auto">
        <Skeleton height="48px" width="384px" className="mx-auto mb-16" />
        <div className="space-y-6">
          {[...Array(3)].map((_, i) => (
            <Skeleton key={i} height="96px" variant="rectangular" />
          ))}
        </div>
      </div>
    </section>
  );
}

export { Skeleton, SkeletonCard, SkeletonButton, SkeletonAvatar, StatsSkeleton, TestimonialsSkeleton, FAQSkeleton };
