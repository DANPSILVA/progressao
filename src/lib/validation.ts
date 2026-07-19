import { z } from 'zod';

export const registerSchema = z.object({
  name: z.string().min(2, 'Nome muito curto').max(60),
  characterName: z.string().min(2, 'Nome do personagem muito curto').max(60),
  email: z.string().email('Email inválido'),
  password: z.string().min(8, 'Senha deve ter ao menos 8 caracteres'),
});

export const loginSchema = z.object({
  email: z.string().email('Email inválido'),
  password: z.string().min(1, 'Senha obrigatória'),
});

const emptyToUndefined = (val: unknown) => (val === '' || val === null || val === undefined ? undefined : val);

export const damageTypeEntrySchema = z.object({
  type: z.string(),
  amount: z.number(),
  percentage: z.number(),
});

export const damageSourceEntrySchema = z.object({
  name: z.string(),
  amount: z.number(),
  percentage: z.number(),
});

export const huntSessionSchema = z.object({
  startedAt: z.coerce.date(),
  durationMin: z.coerce.number().int().positive('Duração deve ser maior que zero'),
  xpGained: z.coerce.number().int().min(0),
  profit: z.coerce.number().int().default(0),
  waste: z.coerce.number().int().default(0),
  loot: z.coerce.number().int().default(0),
  bosses: z.coerce.number().int().min(0).default(0),
  deaths: z.coerce.number().int().min(0).default(0),
  levelAfter: z.preprocess(emptyToUndefined, z.coerce.number().int().positive().optional()),
  damageReceived: z.preprocess(emptyToUndefined, z.coerce.number().int().min(0).optional()),
  maxDps: z.preprocess(emptyToUndefined, z.coerce.number().int().min(0).optional()),
  damageTypes: z.preprocess(emptyToUndefined, z.array(damageTypeEntrySchema).optional()),
  damageSources: z.preprocess(emptyToUndefined, z.array(damageSourceEntrySchema).optional()),
});

export const characterSchema = z.object({
  name: z.string().min(2).max(60),
  vocation: z.string().max(40).optional().nullable(),
  level: z.coerce.number().int().positive(),
  avatarUrl: z.string().url().optional().nullable(),
});

export const friendRequestSchema = z.object({
  email: z.string().email('Email inválido'),
});
