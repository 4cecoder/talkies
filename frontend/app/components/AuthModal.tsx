'use client';

import { useState, useEffect, FormEvent } from 'react';
import { X, Mail, Lock, User, AlertCircle } from 'lucide-react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { useSignIn, useSignUp } from '../lib/hooks/use-auth';
import { signInSchema, signUpSchema } from '../lib/validations/auth';
import { z } from 'zod';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialMode?: 'login' | 'signup';
}

interface FormErrors {
  name?: string;
  email?: string;
  password?: string;
  general?: string;
}

interface FormData {
  name: string;
  email: string;
  password: string;
  rememberMe: boolean;
}

export default function AuthModal({ isOpen, onClose, initialMode = 'login' }: AuthModalProps) {
  const [mode, setMode] = useState<'login' | 'signup'>(initialMode);
  const [errors, setErrors] = useState<FormErrors>({});
  const [formData, setFormData] = useState<FormData>({
    name: '',
    email: '',
    password: '',
    rememberMe: false,
  });

  const signInMutation = useSignIn();
  const signUpMutation = useSignUp();

  const isLoading = signInMutation.isPending || signUpMutation.isPending;

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
      setErrors({});
      setFormData({ name: '', email: '', password: '', rememberMe: false });
      // Reset mutations on open
      signInMutation.reset();
      signUpMutation.reset();
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen]);

  // Handle mutation errors
  useEffect(() => {
    if (signInMutation.error) {
      setErrors({ general: signInMutation.error.message });
    }
    if (signUpMutation.error) {
      setErrors({ general: signUpMutation.error.message });
    }
  }, [signInMutation.error, signUpMutation.error]);

  // Handle successful auth
  useEffect(() => {
    if (signInMutation.isSuccess || signUpMutation.isSuccess) {
      onClose();
    }
  }, [signInMutation.isSuccess, signUpMutation.isSuccess, onClose]);

  const validateForm = (): boolean => {
    const newErrors: FormErrors = {};

    try {
      if (mode === 'signup') {
        signUpSchema.parse({
          name: formData.name,
          email: formData.email,
          password: formData.password,
        });
      } else {
        signInSchema.parse({
          email: formData.email,
          password: formData.password,
          rememberMe: formData.rememberMe,
        });
      }
    } catch (error) {
      if (error instanceof z.ZodError) {
        error.issues.forEach((issue) => {
          const field = issue.path[0] as keyof FormErrors;
          if (field) {
            newErrors[field] = issue.message;
          }
        });
      }
      setErrors(newErrors);
      return false;
    }

    setErrors({});
    return true;
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setErrors({});

    if (mode === 'signup') {
      signUpMutation.mutate({
        name: formData.name,
        email: formData.email,
        password: formData.password,
      });
    } else {
      signInMutation.mutate({
        email: formData.email,
        password: formData.password,
        rememberMe: formData.rememberMe,
      });
    }
  };

  const handleModeSwitch = () => {
    setMode(mode === 'login' ? 'signup' : 'login');
    setErrors({});
    signInMutation.reset();
    signUpMutation.reset();
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
      <div className="relative w-full max-w-md animate-scale-in">
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

            {/* General error message */}
            {errors.general && (
              <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20 flex items-center gap-2 text-red-400 text-sm">
                <AlertCircle size={16} />
                {errors.general}
              </div>
            )}

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
                  disabled={isLoading}
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
                disabled={isLoading}
              />

              <Input
                label="Password"
                type="password"
                placeholder="••••••••"
                icon={<Lock size={20} />}
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                error={errors.password}
                helperText={mode === 'signup' ? 'Min 8 chars with uppercase, lowercase, and number' : undefined}
                required
                autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                disabled={isLoading}
              />

              {mode === 'login' && (
                <div className="flex items-center justify-between text-sm">
                  <label className="flex items-center text-neutral-400 cursor-pointer hover:text-white transition-colors">
                    <input
                      type="checkbox"
                      className="mr-2 rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500"
                      checked={formData.rememberMe}
                      onChange={(e) => setFormData({ ...formData, rememberMe: e.target.checked })}
                      disabled={isLoading}
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
                disabled={isLoading}
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
                    disabled={isLoading}
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
                    disabled={isLoading}
                  >
                    Sign in
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
