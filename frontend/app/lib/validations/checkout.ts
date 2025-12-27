import { z } from 'zod';

export const createCheckoutSchema = z.object({
  priceId: z
    .string()
    .regex(/^price_[a-zA-Z0-9]+$/, 'Invalid Stripe price ID'),
  billingCycle: z.enum(['monthly', 'annual']),
});

export const webhookEventSchema = z.object({
  id: z.string(),
  type: z.string(),
  data: z.object({
    object: z.record(z.string(), z.unknown()),
  }),
});

export type CreateCheckoutInput = z.infer<typeof createCheckoutSchema>;
export type WebhookEvent = z.infer<typeof webhookEventSchema>;
