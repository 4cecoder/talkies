import { HTMLAttributes, forwardRef } from 'react';
import { cn } from '@/app/lib/utils';

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'interactive' | 'gradient-border';
  noPadding?: boolean;
}

const Card = forwardRef<HTMLDivElement, CardProps>(
  (
    {
      className,
      variant = 'default',
      noPadding = false,
      children,
      ...props
    },
    ref
  ) => {
    const baseStyles = cn(
      'rounded-3xl backdrop-blur-xl',
      !noPadding && 'p-6',
      'transition-all duration-200'
    );

    const variants = {
      default: cn(
        'bg-white/5 border border-white/10'
      ),
      interactive: cn(
        'bg-white/5 border border-white/10',
        'hover:bg-white/8 hover:border-white/20',
        'hover:shadow-xl hover:scale-[1.02]',
        'cursor-pointer',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:ring-offset-2 focus-visible:ring-offset-[#0a0a0f]'
      ),
      'gradient-border': cn(
        'relative',
        'before:absolute before:inset-0 before:-z-10 before:rounded-3xl',
        'before:bg-gradient-to-r before:from-purple-500 before:via-pink-500 before:to-blue-500',
        'before:p-[1px]',
        'bg-white/5',
        'hover:before:p-[2px]'
      ),
    };

    return (
      <div
        ref={ref}
        className={cn(baseStyles, variants[variant], className)}
        {...props}
      >
        {children}
      </div>
    );
  }
);

Card.displayName = 'Card';

const CardHeader = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn('flex flex-col space-y-1.5', className)}
      {...props}
    />
  )
);
CardHeader.displayName = 'CardHeader';

const CardTitle = forwardRef<HTMLHeadingElement, HTMLAttributes<HTMLHeadingElement>>(
  ({ className, children, ...props }, ref) => (
    <h3
      ref={ref}
      className={cn('text-2xl font-bold text-white', className)}
      {...props}
    >
      {children}
    </h3>
  )
);
CardTitle.displayName = 'CardTitle';

const CardDescription = forwardRef<HTMLParagraphElement, HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => (
    <p
      ref={ref}
      className={cn('text-sm text-neutral-300', className)}
      {...props}
    />
  )
);
CardDescription.displayName = 'CardDescription';

const CardContent = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('pt-0', className)} {...props} />
  )
);
CardContent.displayName = 'CardContent';

const CardFooter = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn('flex items-center pt-4', className)}
      {...props}
    />
  )
);
CardFooter.displayName = 'CardFooter';

export { Card, CardHeader, CardFooter, CardTitle, CardDescription, CardContent };
