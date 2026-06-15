import { z } from "zod";

// --- User ---
export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().nullable(),
  avatar_url: z.string().url().nullable(),
  plan: z.enum(["free", "pro", "enterprise"]),
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
});
export type User = z.infer<typeof UserSchema>;

// --- BirthProfile ---
export const BirthProfileSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  label: z.string().min(1).max(100),
  name: z.string().min(1).max(200),
  birth_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  birth_time: z.string().regex(/^\d{2}:\d{2}$/).nullable(),
  birth_city: z.string().min(1).max(200),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timezone: z.string().min(1),
  is_primary: z.boolean(),
  created_at: z.coerce.date(),
});
export type BirthProfile = z.infer<typeof BirthProfileSchema>;

// --- ChartResult ---
export const ChartResultSchema = z.object({
  id: z.string().uuid(),
  birth_profile_id: z.string().uuid(),
  house_system: z.string(),
  ayanamsa: z.string().nullable(),
  chart_data: z.record(z.unknown()),
  created_at: z.coerce.date(),
});
export type ChartResult = z.infer<typeof ChartResultSchema>;

// --- Job ---
export const JobStatusSchema = z.enum(["queued", "processing", "complete", "failed"]);
export const JobTypeSchema = z.enum(["report", "llm_interpretation"]);
export const JobSchema = z.object({
  id: z.string(),
  user_id: z.string().uuid(),
  type: JobTypeSchema,
  status: JobStatusSchema,
  birth_profile_id: z.string().uuid(),
  config: z.record(z.unknown()),
  result_url: z.string().url().nullable(),
  error: z.string().nullable(),
  created_at: z.coerce.date(),
  completed_at: z.coerce.date().nullable(),
});
export type Job = z.infer<typeof JobSchema>;

// --- Report ---
export const ReportTypeSchema = z.enum([
  "natal", "career", "relationship", "yearly", "compatibility", "dasha",
]);
export const ReportSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  birth_profile_id: z.string().uuid(),
  job_id: z.string(),
  type: ReportTypeSchema,
  version: z.string(),
  storage_url: z.string().url(),
  pdf_url: z.string().url().nullable(),
  share_token: z.string().nullable(),
  share_expires_at: z.coerce.date().nullable(),
  generated_at: z.coerce.date(),
});
export type Report = z.infer<typeof ReportSchema>;

// --- API Envelope ---
export const ApiSuccessSchema = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({ success: z.literal(true), data: dataSchema });

export const ApiErrorSchema = z.object({
  success: z.literal(false),
  error: z.object({ code: z.string(), message: z.string() }),
});
