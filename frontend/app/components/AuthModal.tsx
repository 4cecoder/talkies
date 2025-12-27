'use client';

import { useState, useEffect, useRef, FormEvent } from 'react';
import { X, Mail, Lock, User } from './icons';
import { Button } from './ui/Button';
import { Input } from './ui/Input';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialMode?: 'login' | 'signup';
}

interface FormErrors {
  name?: string;
  email?: string;
  password?: string;
}

interface FormData {
  name: string;
  email: string;
  password: string;
  rememberMe: boolean;
}

export default function AuthModal({ isOpen, onClose, initialMode = 'login' }: AuthModalProps) {
  const [mode, setMode] = useState<'login' | 'signup'>(initialMode);
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<FormErrors>({});
  const [formData, setFormData] = useState<FormData>({
    name: '',
    email: '',
    password: '',
    rememberMe: false,
  });
  const modalRef = useRef<HTMLDivElement>(null);
  const firstInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
      setErrors({});
      setFormData({ name: '', email: '', password: '', rememberMe: false });
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  // Handle Escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
    };
  }, [isOpen, onClose]);

  // Focus trap
  useEffect(() => {
    if (!isOpen || !modalRef.current) return;

    const focusableElements = modalRef.current.querySelectorAll(
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"]):not([disabled])'
    );
    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;

    const handleTab = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;

      if (e.shiftKey) {
        if (document.activeElement === firstElement) {
          e.preventDefault();
          lastElement?.focus();
        }
      } else {
        if (document.activeElement === lastElement) {
          e.preventDefault();
          firstElement?.focus();
        }
      }
    };

    document.addEventListener('keydown', handleTab);

    // Auto-focus first input
    setTimeout(() => {
      const firstInput = modalRef.current?.querySelector('input');
      firstInput?.focus();
    }, 100);

    return () => {
      document.removeEventListener('keydown', handleTab);
    };
  }, [isOpen, mode]);

  const validateForm = (): boolean => {
    const newErrors: FormErrors = {};

    if (mode === 'signup' && !formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    if (!formData.password) {
      newErrors.password = 'Password is required';
    } else if (formData.password.length < 8) {
      newErrors.password = 'Password must be at least 8 characters';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setIsLoading(true);

    try {
      await new Promise(resolve => setTimeout(resolve, 1500));
      // TODO: Implement actual authentication
      onClose();
    } catch (error) {
      // Error handling would go here
      setIsLoading(false);
    } finally {
      setIsLoading(false);
    }
  };

  const handleModeSwitch = () => {
    setMode(mode === 'login' ? 'signup' : 'login');
    setErrors({});
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="auth-modal-title"
    >
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-md animate-fade-in"
        onClick={onClose}
        aria-hidden="true"
      ></div>

      {/* Modal */}
      <div ref={modalRef} className="relative w-full max-w-md animate-scale-in">
        <div className="relative rounded-3xl overflow-hidden">
          {/* Animated gradient border */}
          <div className="absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600 animate-gradient"></div>
          <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>

          {/* Content */}
          <div className="relative p-8">
            <button
              onClick={onClose}
              className="absolute top-4 right-4 text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded-lg p-1"
              aria-label="Close dialog"
            >
              <X className="w-6 h-6" />
            </button>

            <h2 id="auth-modal-title" className="text-3xl font-bold mb-2">
              <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                {mode === 'login' ? 'Welcome Back' : 'Get Started'}
              </span>
            </h2>
            <p className="text-neutral-400 mb-8">
              {mode === 'login' ? 'Sign in to your account' : 'Create your account'}
            </p>

            <form className="space-y-4" onSubmit={handleSubmit} noValidate>
              {mode === 'signup' && (
                <Input
                  label="Name"
                  type="text"
                  placeholder="Your name"
                  icon={<User size={20} />}
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  error={errors.name}
                  required
                  autoComplete="name"
                />
              )}

              <Input
                label="Email"
                type="email"
                placeholder="you@example.com"
                icon={<Mail size={20} />}
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                error={errors.email}
                required
                autoComplete="email"
              />

              <Input
                label="Password"
                type="password"
                placeholder="••••••••"
                icon={<Lock size={20} />}
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                error={errors.password}
                helperText={mode === 'signup' ? 'Must be at least 8 characters' : undefined}
                required
                autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              />

              {mode === 'login' && (
                <div className="flex items-center justify-between text-sm">
                  <label className="flex items-center text-neutral-400 cursor-pointer hover:text-white transition-colors">
                    <input
                      type="checkbox"
                      className="mr-2 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500"
                      checked={formData.rememberMe}
                      onChange={(e) => setFormData({ ...formData, rememberMe: e.target.checked })}
                    />
                    Remember me
                  </label>
                  <a
                    href="#"
                    className="text-purple-400 hover:text-purple-300 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-1"
                  >
                    Forgot password?
                  </a>
                </div>
              )}

              <Button
                type="submit"
                variant="gradient"
                size="lg"
                fullWidth
                isLoading={isLoading}
              >
                {mode === 'login' ? 'Sign In' : 'Create Account'}
              </Button>
            </form>

            <div className="mt-6 text-center text-sm text-neutral-400">
              {mode === 'login' ? (
                <>
                  Don&apos;t have an account?{' '}
                  <button
                    type="button"
                    onClick={handleModeSwitch}
                    className="text-purple-400 hover:text-purple-300 transition-colors font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-1"
                  >
                    Sign up
                  </button>
                </>
              ) : (
                <>
                  Already have an account?{' '}
                  <button
                    type="button"
                    onClick={handleModeSwitch}
                    className="text-purple-400 hover:text-purple-300 transition-colors font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-1"
                  >
                    Sign in
                  </button>
                </>
              )}
            </div>

            <div className="mt-8 pt-6 border-t border-white/10">
              <p className="text-center text-sm text-neutral-500 mb-4">Or continue with</p>
              <div className="grid grid-cols-2 gap-3">
                <Button
                  variant="secondary"
                  type="button"
                  className="gap-2"
                  aria-label="Sign in with Google"
                >
                  <svg className="w-5 h-5" viewBox="0 0 24 24" aria-hidden="true">
                    <path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                    <path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                    <path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                    <path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                  </svg>
                  Google
                </Button>
                <Button
                  variant="secondary"
                  type="button"
                  className="gap-2"
                  aria-label="Sign in with GitHub"
                >
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                  </svg>
                  GitHub
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
