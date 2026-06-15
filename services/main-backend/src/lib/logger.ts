import pino from "pino";

const logLevel = process.env["LOG_LEVEL"] || "info";
const isProduction = process.env["NODE_ENV"] === "production";

export const logger = pino({
  level: logLevel,
  transport: !isProduction
    ? {
        target: "pino-pretty",
        options: {
          colorize: true,
          translateTime: "HH:MM:ss Z",
          ignore: "pid,hostname",
        },
      }
    : undefined,
});

export type Logger = typeof logger;
